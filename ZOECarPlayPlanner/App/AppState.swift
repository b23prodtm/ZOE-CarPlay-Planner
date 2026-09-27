import SwiftUI
import CoreLocation
import MapKit
import UIKit

// MARK: - AppState

/// État global partagé entre toutes les vues et CarPlay.
@MainActor
final class AppState: ObservableObject {

    // MARK: - Services

    private let mockVehicleService = MockRenaultVehicleService()
    private let routingProvider: RoutingProvider = AppleRoutingProvider()
    private let chargingPlanner = ChargingPlanner()
    private let stationProvider: ChargingStationProvider = MockChargingStationProvider()

    // Authentification & service réel (partagés entre AppState et SettingsView)
    let auth = RenaultAuthentication()
    private var realService: RealRenaultVehicleService?

    private static let routeHistoryKey = "RouteHistory"
    private static let maxHistoryEntries = 20

    /// Service actif selon le mode (simulation ou réel).
    private var activeVehicleService: any RenaultVehicleService {
        if settings.useSimulationMode || realService == nil {
            return mockVehicleService
        }
        return realService!
    }

    // MARK: - Published State

    @Published var settings: PlannerSettings = PlannerSettings.load()
    @Published var vehicleStatus: VehicleStatus?
    @Published var chargingPlan: ChargingPlan?
    @Published var currentRoute: Route?
    @Published var isLoading: Bool = false
    @Published var error: AppError?
    @Published var isAuthenticated: Bool = false
    @Published var routeHistory: [PlannedTrip] = []
    @Published var recentPlaces: [TripPlace] = []
    @Published var lastPlannedTrip: PlannedTrip?
    @Published var availableStationsOnRoute: [ChargingStation] = []
    @Published var availableNavigationApps: [PreferredNavigationApp] = []
    @Published var currentVehicleLocation: CLLocationCoordinate2D?
    @Published private(set) var selectedStationIDsByStop: [UUID: UUID] = [:]
    @Published var chargingStationSelectionPreference: ChargingStationSelectionPreference = .balanced

    // MARK: - Init

    init() {
        routeHistory = loadRouteHistory()
        recentPlaces = buildRecentPlaces(from: routeHistory)
        refreshAvailableNavigationApps()

        Task {
            // Vérifier si des credentials existent déjà et construire le service réel
            await checkExistingCredentials()
            await refreshVehicleStatus()
        }
    }

    // MARK: - Authentication

    /// Connecte au compte Renault et bascule sur le service réel.
    func connectRenault(email: String, password: String, vin: String) async {
        isLoading = true
        defer { isLoading = false }
        error = nil
        do {
            try await auth.storeCredentials(email: email, password: password)
            buildRealService(vin: vin)
            settings.useSimulationMode = false
            settings.save()
            isAuthenticated = true
            await refreshVehicleStatus()
        } catch {
            self.error = AppError.from(error)
        }
    }

    /// Déconnecte du compte Renault et repasse en simulation.
    func disconnectRenault() async {
        await auth.clearCredentials()
        realService = nil
        settings.useSimulationMode = true
        settings.save()
        isAuthenticated = false
        currentVehicleLocation = nil
    }

    // MARK: - Vehicle

    func refreshVehicleStatus() async {
        isLoading = true
        defer { isLoading = false }
        do {
            vehicleStatus = try await activeVehicleService.getVehicleStatus()
            currentVehicleLocation = try? await activeVehicleService.getVehicleLocation()
        } catch {
            self.error = AppError.from(error)
        }
    }

    // MARK: - Planning

    func planRoute(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) async {
        let originName = String(format: "%.4f, %.4f", origin.latitude, origin.longitude)
        let destinationName = String(format: "%.4f, %.4f", destination.latitude, destination.longitude)
        let originPlace = TripPlace(name: originName, coordinate: origin)
        let destinationPlace = TripPlace(name: destinationName, coordinate: destination)
        await planTrip(origin: originPlace, destination: destinationPlace, waypoints: [])
    }

    func planTrip(origin: TripPlace, destination: TripPlace, waypoints: [TripPlace], preferences: RoutePreferences? = nil) async {
        isLoading = true
        defer { isLoading = false }
        error = nil
        chargingPlan = nil
        availableStationsOnRoute = []
        selectedStationIDsByStop = [:]
        chargingStationSelectionPreference = .balanced

        do {
            let effectivePreferences = preferences ?? settings.routePreferences
            let points = [origin] + waypoints + [destination]
            guard points.count >= 2 else { throw RoutingError.invalidCoordinates }

            var totalDistanceKm = 0.0
            var totalDurationMinutes = 0.0
            var weightedHighway = 0.0
            var weightedRoad = 0.0
            var weightedCity = 0.0
            var segmentDistances: [Double] = []
            var routePath: [RouteCoordinate] = []

            for index in 0..<(points.count - 1) {
                let segment = try await routingProvider.calculateRoute(
                    from: points[index].coordinate,
                    to: points[index + 1].coordinate,
                    preferences: effectivePreferences
                )

                totalDistanceKm += segment.totalDistanceKm
                totalDurationMinutes += segment.estimatedDurationMinutes
                weightedHighway += segment.roadType.highwayPercent * segment.totalDistanceKm
                weightedRoad += segment.roadType.roadPercent * segment.totalDistanceKm
                weightedCity += segment.roadType.cityPercent * segment.totalDistanceKm
                segmentDistances.append(segment.totalDistanceKm)
                if routePath.isEmpty {
                    routePath = segment.path
                } else if routePath.last == segment.path.first {
                    routePath.append(contentsOf: segment.path.dropFirst())
                } else {
                    routePath.append(contentsOf: segment.path)
                }
            }

            let waypointDistances = Self.cumulativeDistances(for: Array(segmentDistances.dropLast()))
            let routeWaypoints = zip(waypoints, waypointDistances).map { waypoint, distance in
                RoutePoint(
                    name: waypoint.name,
                    coordinate: waypoint.coordinate,
                    distanceFromOriginKm: distance
                )
            }

            let roadType: RoadTypeDistribution
            if totalDistanceKm > 0 {
                roadType = RoadTypeDistribution(
                    highwayPercent: weightedHighway / totalDistanceKm,
                    roadPercent: weightedRoad / totalDistanceKm,
                    cityPercent: weightedCity / totalDistanceKm
                )
            } else {
                roadType = .typical
            }

            let route = Route(
                origin: RoutePoint(name: origin.name, coordinate: origin.coordinate, distanceFromOriginKm: 0),
                destination: RoutePoint(name: destination.name, coordinate: destination.coordinate, distanceFromOriginKm: totalDistanceKm),
                totalDistanceKm: totalDistanceKm,
                estimatedDurationMinutes: totalDurationMinutes,
                waypoints: routeWaypoints,
                roadType: roadType,
                routePreferences: effectivePreferences,
                path: routePath
            )
            currentRoute = route

            let trip = PlannedTrip(
                origin: origin,
                destination: destination,
                waypoints: waypoints,
                preferences: effectivePreferences
            )

            let stations = try await stationProvider.findStations(
                along: route,
                connectorTypes: settings.selectedConnectorTypes,
                networks: settings.selectedChargingNetworks
            )
            availableStationsOnRoute = stations
            lastPlannedTrip = trip
            addToHistory(trip)

            rebuildChargingPlan()
        } catch {
            self.error = AppError.from(error)
        }
    }

    func relaunchTripFromHistory(_ trip: PlannedTrip) async {
        settings.routePreferences = trip.preferences
        await planTrip(origin: trip.origin, destination: trip.destination, waypoints: trip.waypoints, preferences: trip.preferences)
    }

    func refreshRouteFromCurrentVehicleLocation() async {
        guard let plannedTrip = lastPlannedTrip ?? routeHistory.first else { return }

        do {
            let latestLocation = try await activeVehicleService.getVehicleLocation()
            guard let latestLocation else { return }
            currentVehicleLocation = latestLocation

            let refreshedOrigin = TripPlace(name: "Position actuelle du véhicule", coordinate: latestLocation)
            await planTrip(
                origin: refreshedOrigin,
                destination: plannedTrip.destination,
                waypoints: plannedTrip.waypoints,
                preferences: plannedTrip.preferences
            )
        } catch {
            self.error = AppError.from(error)
        }
    }

    @discardableResult
    func openCurrentTripInPreferredNavigationApp(includeChargingStops: Bool = true) -> Bool {
        guard let route = currentRoute else { return false }

        var navigationPoints: [(distance: Double, priority: Int, name: String, coordinate: CLLocationCoordinate2D)] = [
            (0, 0, route.origin.name, route.origin.coordinate)
        ]

        for point in route.waypoints {
            navigationPoints.append((point.distanceFromOriginKm, 0, point.name, point.coordinate))
        }

        navigationPoints.append((route.totalDistanceKm, 0, route.destination.name, route.destination.coordinate))

        if includeChargingStops, let plan = chargingPlan {
            for stop in plan.stops {
                guard let station = selectedStation(for: stop) else { continue }
                navigationPoints.append((stop.distanceFromOriginKm, 1, station.name, station.coordinate))
            }
        }

        let sortedPoints = navigationPoints
            .sorted {
                if abs($0.distance - $1.distance) < 0.01 {
                    return $0.priority < $1.priority
                }
                return $0.distance < $1.distance
            }

        var mandatoryPoints = sortedPoints.filter { $0.priority == 0 }
        var optionalPoints: [(distance: Double, priority: Int, name: String, coordinate: CLLocationCoordinate2D)] = []

        for point in sortedPoints where point.priority == 1 {
            if let mandatoryIndex = mandatoryPoints.firstIndex(where: {
                abs($0.coordinate.latitude - point.coordinate.latitude) < 0.0001
                && abs($0.coordinate.longitude - point.coordinate.longitude) < 0.0001
            }) {
                mandatoryPoints[mandatoryIndex].name += " • \(point.name)"
                continue
            }

            let duplicateOptional = optionalPoints.contains {
                abs($0.coordinate.latitude - point.coordinate.latitude) < 0.0001
                && abs($0.coordinate.longitude - point.coordinate.longitude) < 0.0001
            }
            if !duplicateOptional {
                optionalPoints.append(point)
            }
        }

        let maxMapItems = 10

        var limitedPoints = mandatoryPoints.sorted { $0.distance < $1.distance }
        guard limitedPoints.count <= maxMapItems else {
            return false
        }

        if limitedPoints.count < maxMapItems {
            let availableSlots = maxMapItems - limitedPoints.count
            limitedPoints.append(contentsOf: optionalPoints.prefix(availableSlots))
        }

        let routePoints = Array(limitedPoints
            .sorted { $0.distance < $1.distance }
            .prefix(maxMapItems))

        return open(points: routePoints, preferredApp: settings.preferredNavigationApp)
    }

    func setAvoidHighways(_ isEnabled: Bool) {
        settings.routePreferences.avoidHighways = isEnabled
        if isEnabled {
            settings.routePreferences.preferHighways = false
        }
    }

    func setPreferHighways(_ isEnabled: Bool) {
        settings.routePreferences.preferHighways = isEnabled
        if isEnabled {
            settings.routePreferences.avoidHighways = false
        }
    }

    func stationOptions(for stop: ChargingStop) -> [ChargingStation] {
        let thresholdKm = 18.0
        let nearbyStations = availableStationsOnRoute
            .filter { abs($0.distanceFromRouteKm - stop.distanceFromOriginKm) <= thresholdKm }
            .sorted {
                let lhsDelta = abs($0.distanceFromRouteKm - stop.distanceFromOriginKm)
                let rhsDelta = abs($1.distanceFromRouteKm - stop.distanceFromOriginKm)
                switch chargingStationSelectionPreference {
                case .earlier:
                    let lhsEarlier = $0.distanceFromRouteKm <= stop.distanceFromOriginKm
                    let rhsEarlier = $1.distanceFromRouteKm <= stop.distanceFromOriginKm
                    if lhsEarlier != rhsEarlier { return lhsEarlier }
                case .later:
                    let lhsLater = $0.distanceFromRouteKm >= stop.distanceFromOriginKm
                    let rhsLater = $1.distanceFromRouteKm >= stop.distanceFromOriginKm
                    if lhsLater != rhsLater { return lhsLater }
                case .balanced:
                    break
                }
                if abs(lhsDelta - rhsDelta) > 0.1 {
                    return lhsDelta < rhsDelta
                }
                if settings.preferHighwayStations,
                   currentRoute?.routePreferences.avoidHighways != true,
                   $0.isHighway != $1.isHighway {
                    return $0.isHighway == true
                }
                return $0.maxPowerKW > $1.maxPowerKW
            }

        if let station = stop.station,
           !nearbyStations.contains(where: { $0.id == station.id }) {
            return [station] + nearbyStations
        }
        return nearbyStations
    }

    func selectedStation(for stop: ChargingStop) -> ChargingStation? {
        if let selectedStationID = selectedStationIDsByStop[stop.id],
           let station = availableStationsOnRoute.first(where: { $0.id == selectedStationID }) {
            return station
        }
        return stop.station
    }

    func selectStation(_ station: ChargingStation, for stop: ChargingStop) {
        selectedStationIDsByStop[stop.id] = station.id
    }

    func recalculateChargingStops(
        preference: ChargingStationSelectionPreference
    ) {
        chargingStationSelectionPreference = preference
        selectedStationIDsByStop = [:]
        rebuildChargingPlan()
    }

    // MARK: - Private

    nonisolated static func cumulativeDistances(for segmentDistances: [Double]) -> [Double] {
        var running = 0.0
        return segmentDistances.map {
            running += $0
            return running
        }
    }

    private func effectiveConsumptionWhPerKm(baseConsumption: Double, mode: TravelMode) -> Double {
        switch mode {
        case .normal:
            return baseConsumption
        case .eco:
            return baseConsumption * 0.9
        }
    }

    private func rebuildChargingPlan() {
        guard let status = vehicleStatus, let route = currentRoute else { return }

        let input = ChargingPlannerInput(
            currentSOCPercent: status.battery.stateOfChargePercent,
            usableBatteryKWh: settings.vehicle.usableBatteryKWh,
            consumptionWhPerKm: effectiveConsumptionWhPerKm(
                baseConsumption: settings.consumptionWhPerKm,
                mode: route.routePreferences.mode
            ),
            distanceKm: route.totalDistanceKm,
            strategy: ChargingStrategy(
                minimumSOCPercent: settings.minBatteryAtArrivalPercent,
                targetSOCPercent: settings.maxBatteryAfterChargePercent,
                safetyMarginPercent: settings.safetyMarginPercent
            ),
            chargingPowerKW: settings.preferredChargingPowerKW,
            availableStations: availableStationsOnRoute,
            roadTypes: route.roadType,
            preferHighwayStations: settings.preferHighwayStations && !route.routePreferences.avoidHighways,
            stationSelectionPreference: chargingStationSelectionPreference
        )
        chargingPlan = chargingPlanner.plan(input: input)
    }

    @MainActor
    private func addToHistory(_ trip: PlannedTrip) {
        routeHistory.removeAll(where: { $0.matchesPath(as: trip) })
        routeHistory.insert(trip, at: 0)
        if routeHistory.count > Self.maxHistoryEntries {
            routeHistory = Array(routeHistory.prefix(Self.maxHistoryEntries))
        }
        recentPlaces = buildRecentPlaces(from: routeHistory)
        saveRouteHistory()
    }

    private func buildRecentPlaces(from history: [PlannedTrip]) -> [TripPlace] {
        var unique: [TripPlace] = []

        for place in history.flatMap({ $0.allPlaces }) {
            let isDuplicate = unique.contains(where: {
                $0.name == place.name
                && abs($0.latitude - place.latitude) < 0.0001
                && abs($0.longitude - place.longitude) < 0.0001
            })
            if !isDuplicate {
                unique.append(place)
            }
            if unique.count >= 12 {
                break
            }
        }

        return unique
    }

    private func loadRouteHistory() -> [PlannedTrip] {
        guard let data = UserDefaults.standard.data(forKey: Self.routeHistoryKey),
              let history = try? JSONDecoder().decode([PlannedTrip].self, from: data)
        else { return [] }
        return history
    }

    private func saveRouteHistory() {
        guard let data = try? JSONEncoder().encode(routeHistory) else { return }
        UserDefaults.standard.set(data, forKey: Self.routeHistoryKey)
    }

    private func checkExistingCredentials() async {
        guard await auth.hasCredentials else { return }
        let vin = (try? KeychainCredentialStore().retrieve(forKey: "renault_vin")) ?? ""
        guard !vin.isEmpty else { return }
        buildRealService(vin: vin)
        isAuthenticated = true
        settings.useSimulationMode = false
    }

    private func buildRealService(vin: String) {
        let client = RenaultAPIClient(auth: auth)
        realService = RealRenaultVehicleService(apiClient: client, vin: vin)
        try? KeychainCredentialStore().store(value: vin, forKey: "renault_vin")
    }

    func refreshAvailableNavigationApps() {
        let allApps = PreferredNavigationApp.allCases
        availableNavigationApps = allApps.filter { navigationAppIsAvailable($0) }
        if !availableNavigationApps.contains(settings.preferredNavigationApp) {
            settings.preferredNavigationApp = .appleMaps
            settings.save()
        }
    }

    private func navigationAppIsAvailable(_ app: PreferredNavigationApp) -> Bool {
        switch app {
        case .appleMaps:
            return true
        case .googleMaps:
            return UIApplication.shared.canOpenURL(URL(string: "comgooglemaps://")!)
        case .waze:
            return UIApplication.shared.canOpenURL(URL(string: "waze://")!)
        case .roole:
            return UIApplication.shared.canOpenURL(URL(string: "roole://")!)
        }
    }

    private func open(
        points: [(distance: Double, priority: Int, name: String, coordinate: CLLocationCoordinate2D)],
        preferredApp: PreferredNavigationApp
    ) -> Bool {
        guard points.count >= 2 else { return false }

        if preferredApp == .googleMaps || preferredApp == .waze || preferredApp == .roole, points.count > 2 {
            return open(points: points, in: .appleMaps)
        }

        if navigationAppIsAvailable(preferredApp), open(points: points, in: preferredApp) {
            return true
        }

        return open(points: points, in: .appleMaps)
    }

    private func open(
        points: [(distance: Double, priority: Int, name: String, coordinate: CLLocationCoordinate2D)],
        in app: PreferredNavigationApp
    ) -> Bool {
        switch app {
        case .appleMaps:
            let mapItems = points.map { point -> MKMapItem in
                let item = MKMapItem(placemark: MKPlacemark(coordinate: point.coordinate))
                item.name = point.name
                return item
            }
            MKMapItem.openMaps(
                with: mapItems,
                launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving]
            )
            return true
        case .googleMaps:
            guard points.count <= 2 else { return false }
            guard let origin = points.first else { return false }
            var components = URLComponents()
            components.scheme = "comgooglemaps"
            components.queryItems = [
                URLQueryItem(name: "saddr", value: "\(origin.coordinate.latitude),\(origin.coordinate.longitude)"),
                URLQueryItem(name: "daddr", value: "\(points[1].coordinate.latitude),\(points[1].coordinate.longitude)"),
                URLQueryItem(name: "directionsmode", value: "driving")
            ]
            guard let url = components.url else { return false }
            UIApplication.shared.open(url)
            return true
        case .waze:
            guard points.count <= 2 else { return false }
            guard let destination = points.last else { return false }
            var components = URLComponents()
            components.scheme = "waze"
            components.queryItems = [
                URLQueryItem(name: "ll", value: "\(destination.coordinate.latitude),\(destination.coordinate.longitude)"),
                URLQueryItem(name: "navigate", value: "yes")
            ]
            guard let url = components.url else { return false }
            UIApplication.shared.open(url)
            return true
        case .roole:
            guard points.count <= 2 else { return false }
            guard let destination = points.last else { return false }
            var components = URLComponents()
            components.scheme = "roole"
            components.queryItems = [
                URLQueryItem(name: "destination", value: "\(destination.coordinate.latitude),\(destination.coordinate.longitude)")
            ]
            guard let url = components.url else { return false }
            UIApplication.shared.open(url)
            return true
        }
    }
}

private extension PlannedTrip {
    func matchesPath(as other: PlannedTrip) -> Bool {
        guard origin.matches(as: other.origin), destination.matches(as: other.destination) else {
            return false
        }

        guard waypoints.count == other.waypoints.count else { return false }
        for (lhs, rhs) in zip(waypoints, other.waypoints) {
            if !lhs.matches(as: rhs) {
                return false
            }
        }

        return preferences == other.preferences
    }
}

private extension TripPlace {
    func matches(as other: TripPlace) -> Bool {
        let sameName = name == other.name
        let sameLatitude = abs(latitude - other.latitude) < 0.0001
        let sameLongitude = abs(longitude - other.longitude) < 0.0001
        return sameName && sameLatitude && sameLongitude
    }
}
