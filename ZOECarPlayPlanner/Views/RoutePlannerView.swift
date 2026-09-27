import SwiftUI
import CoreLocation
import MapKit

private let plannerDefaultRegion = MKCoordinateRegion(
    center: CLLocationCoordinate2D(latitude: 46.4, longitude: 4.7),
    span: MKCoordinateSpan(latitudeDelta: 5.0, longitudeDelta: 5.0)
)

struct RoutePlannerView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var locationManager = PlannerLocationManager()

    @State private var selectedOrigin: TripPlace?
    @State private var selectedDestination: TripPlace?
    @State private var waypoints: [TripPlace] = []
    @State private var pickerContext: LocationPickerContext?
    @State private var detailMapPosition: MapCameraPosition = .region(plannerDefaultRegion)
    @State private var selectionError: AppError?

    private var mapPoints: [PlannerMapPoint] {
        var points: [PlannerMapPoint] = []

        if let origin = selectedOrigin {
            points.append(
                PlannerMapPoint(
                    id: "origin",
                    title: "Départ",
                    subtitle: origin.name,
                    coordinate: origin.coordinate,
                    tint: .blue,
                    symbol: "play.circle.fill"
                )
            )
        }

        if let destination = selectedDestination {
            points.append(
                PlannerMapPoint(
                    id: "destination",
                    title: "Destination",
                    subtitle: destination.name,
                    coordinate: destination.coordinate,
                    tint: .red,
                    symbol: "flag.circle.fill"
                )
            )
        }

        for (index, waypoint) in waypoints.enumerated() {
            points.append(
                PlannerMapPoint(
                    id: "waypoint-\(waypoint.id.uuidString)",
                    title: "Étape \(index + 1)",
                    subtitle: waypoint.name,
                    coordinate: waypoint.coordinate,
                    tint: .purple,
                    symbol: "point.topleft.down.curvedto.point.bottomright.up"
                )
            )
        }

        for station in appState.availableStationsOnRoute {
            points.append(
                PlannerMapPoint(
                    id: "station-\(station.id.uuidString)",
                    title: station.name,
                    subtitle: "\(station.operatorName) • \(station.locationTypeLabel)",
                    coordinate: station.coordinate,
                    tint: station.isHighway == true ? .green : .orange,
                    symbol: station.mapSymbolName
                )
            )
        }

        return points
    }

    private var routePolyline: MKPolyline? {
        let coordinates = appState.currentRoute?.path.map(\.coordinate) ?? []
        guard coordinates.count >= 2 else { return nil }
        return MKPolyline(coordinates: coordinates, count: coordinates.count)
    }

    private var canCalculateRoute: Bool {
        guard let origin = selectedOrigin, let destination = selectedDestination else { return false }
        return !samePlace(origin, destination)
    }

    var body: some View {
        NavigationStack {
            Form {
                routeSection
                chargingFilterSection
                preferenceSection
                calculateSection
                loadingSection
                detailedMapSection
                resultSection
                historySection
            }
            .navigationTitle("Planifier un trajet")
            .sheet(item: $pickerContext) { context in
                LocationPickerSheet(
                    title: context.target.title,
                    recentPlaces: appState.recentPlaces,
                    allowsCurrentLocation: context.target == .origin,
                    locationManager: locationManager,
                    onSelect: { place in
                        applySelection(place, for: context.target)
                    }
                )
            }
            .alert("Sélection impossible", isPresented: Binding(
                get: { selectionError != nil },
                set: { if !$0 { selectionError = nil } }
            )) {
                Button("OK") { selectionError = nil }
            } message: {
                Text(selectionError?.message ?? "")
            }
            .onAppear {
                restoreInitialPlacesIfNeeded()
                fitMapToContent()
            }
            .onChange(of: selectedOrigin?.id) { _, _ in fitMapToContent() }
            .onChange(of: selectedDestination?.id) { _, _ in fitMapToContent() }
            .onChange(of: waypoints.map(\.id)) { _, _ in fitMapToContent() }
            .onChange(of: appState.currentRoute?.path.count ?? 0) { _, _ in fitMapToContent() }
            .onChange(of: appState.availableStationsOnRoute.map(\.id)) { _, _ in fitMapToContent() }
        }
    }

    @ViewBuilder
    private var routeSection: some View {
        Section("Trajet") {
            Button {
                Task { await useCurrentLocationAsOrigin() }
            } label: {
                Label("Utiliser ma position GPS actuelle", systemImage: "location.fill")
            }
            .foregroundStyle(.blue)

            Button {
                pickerContext = .init(target: .origin)
            } label: {
                labeledPlaceRow(title: "Départ", place: selectedOrigin, placeholder: "Choisir sur la carte")
            }
            .foregroundStyle(.primary)

            Button {
                pickerContext = .init(target: .destination)
            } label: {
                labeledPlaceRow(title: "Destination", place: selectedDestination, placeholder: "Choisir sur la carte")
            }
            .foregroundStyle(.primary)

            ForEach(Array(waypoints.enumerated()), id: \.element.id) { index, waypoint in
                HStack(spacing: 8) {
                    Button {
                        pickerContext = .init(target: .waypoint(waypoint.id))
                    } label: {
                        labeledPlaceRow(title: "Étape \(index + 1)", place: waypoint, placeholder: "Choisir")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Étape \(index + 1)")
                    .accessibilityValue(waypoint.name)

                    Button {
                        moveWaypoint(at: index, offset: -1)
                    } label: {
                        Image(systemName: "chevron.up")
                    }
                    .buttonStyle(.borderless)
                    .disabled(index == 0)
                    .accessibilityLabel("Monter cette étape")

                    Button {
                        moveWaypoint(at: index, offset: 1)
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                    .buttonStyle(.borderless)
                    .disabled(index == waypoints.count - 1)
                    .accessibilityLabel("Descendre cette étape")

                    Button(role: .destructive) {
                        removeWaypoint(at: index)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Supprimer cette étape")
                }
            }

            Button {
                pickerContext = .init(target: .newWaypoint)
            } label: {
                Label("Ajouter une étape", systemImage: "plus.circle")
            }
            .foregroundStyle(.blue)
        }
    }

    @ViewBuilder
    private var chargingFilterSection: some View {
        Section("Filtres de recharge") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Réseaux")
                    .font(.subheadline.weight(.semibold))

                ForEach(ChargingNetwork.allCases, id: \.self) { network in
                    Toggle(
                        network.displayName,
                        isOn: binding(for: network)
                    )
                    .tint(.green)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Connecteurs")
                    .font(.subheadline.weight(.semibold))

                ForEach(ConnectorType.allCases, id: \.self) { connector in
                    Toggle(
                        connector.displayName,
                        isOn: connectorBinding(for: connector)
                    )
                    .tint(.blue)
                }
            }

            Text(filterSummaryText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var preferenceSection: some View {
        Section("Mode et préférences") {
            Picker("Mode", selection: $appState.settings.routePreferences.mode) {
                ForEach(TravelMode.allCases, id: \.self) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityHint("Le mode Éco réduit la consommation et peut allonger la durée du trajet.")

            Toggle(
                "Éviter les autoroutes",
                isOn: Binding(
                    get: { appState.settings.routePreferences.avoidHighways },
                    set: { appState.setAvoidHighways($0) }
                )
            )
            .tint(.orange)

            Toggle("Éviter les péages", isOn: $appState.settings.routePreferences.avoidTolls)
                .tint(.orange)

            Toggle(
                "Préférer les autoroutes",
                isOn: Binding(
                    get: { appState.settings.routePreferences.preferHighways },
                    set: { appState.setPreferHighways($0) }
                )
            )
            .tint(.green)

            Toggle("Préférer les routes pittoresques", isOn: $appState.settings.routePreferences.preferScenic)
                .tint(.purple)
        }
    }

    @ViewBuilder
    private var calculateSection: some View {
        Section {
            Button {
                Task { await calculateRoute() }
            } label: {
                Label("Calculer le trajet", systemImage: "arrow.triangle.branch")
            }
            .disabled(!canCalculateRoute)

            if appState.settings.routePreferences != RoutePreferences() {
                Label(appState.settings.routePreferences.summaryText, systemImage: "leaf")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var loadingSection: some View {
        if appState.isLoading {
            Section {
                HStack {
                    ProgressView()
                    Text("Calcul en cours…")
                        .foregroundStyle(.secondary)
                        .padding(.leading, 8)
                }
            }
        }
    }

    @ViewBuilder
    private var detailedMapSection: some View {
        Section("Plan détaillé") {
            Map(position: $detailMapPosition) {
                if let routePolyline {
                    MapPolyline(routePolyline)
                        .stroke(.blue, lineWidth: 5)
                }

                ForEach(mapPoints) { point in
                    Annotation(point.title, coordinate: point.coordinate) {
                        VStack(spacing: 2) {
                            Image(systemName: point.symbol)
                                .font(.caption)
                                .padding(6)
                                .background(point.tint.opacity(0.15))
                                .foregroundStyle(point.tint)
                                .clipShape(Circle())
                            Text(point.title)
                                .font(.caption2)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .frame(height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Button {
                fitMapToContent()
            } label: {
                Label("Ajuster la carte au trajet", systemImage: "scope")
            }
            .foregroundStyle(.blue)

            if routePolyline == nil, appState.currentRoute != nil {
                Text("Le tracé détaillé n'est pas disponible pour cet itinéraire.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !appState.availableStationsOnRoute.isEmpty {
                Text("Bornes visibles sur la carte : \(appState.availableStationsOnRoute.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(appState.availableStationsOnRoute) { station in
                    HStack {
                        Label(station.name, systemImage: station.mapSymbolName)
                        Spacer()
                        Text("\(station.operatorName) • \(station.locationTypeLabel)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var resultSection: some View {
        if let route = appState.currentRoute {
            Section("Résultat") {
                LabeledContent("Distance", value: route.displayDistance)
                LabeledContent("Durée estimée", value: "\(Int(route.estimatedDurationMinutes)) min")
                if !route.waypoints.isEmpty {
                    LabeledContent("Étapes", value: "\(route.waypoints.count)")
                }
            }
        }
    }

    @ViewBuilder
    private var historySection: some View {
        if !appState.routeHistory.isEmpty {
            Section("Historique des recherches") {
                ForEach(Array(appState.routeHistory.prefix(8))) { trip in
                    Button {
                        selectedOrigin = trip.origin
                        selectedDestination = trip.destination
                        waypoints = trip.waypoints
                        appState.settings.routePreferences = trip.preferences
                        Task {
                            await appState.relaunchTripFromHistory(trip)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(trip.summary)
                                .foregroundStyle(.primary)
                            Text(trip.preferences.summaryText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func labeledPlaceRow(title: String, place: TripPlace?, placeholder: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(place?.name ?? placeholder)
                .foregroundStyle(place == nil ? .tertiary : .secondary)
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var filterSummaryText: String {
        let networkCount = appState.settings.selectedChargingNetworks.count
        let connectorCount = appState.settings.selectedConnectorTypes.count
        return "\(networkCount) réseau\(networkCount > 1 ? "x" : "") • \(connectorCount) connecteur\(connectorCount > 1 ? "s" : "")"
    }

    private func binding(for network: ChargingNetwork) -> Binding<Bool> {
        Binding(
            get: { appState.settings.selectedChargingNetworks.contains(network) },
            set: { isEnabled in
                updateSelection(&appState.settings.selectedChargingNetworks, value: network, isEnabled: isEnabled)
            }
        )
    }

    private func connectorBinding(for connector: ConnectorType) -> Binding<Bool> {
        Binding(
            get: { appState.settings.selectedConnectorTypes.contains(connector) },
            set: { isEnabled in
                updateSelection(&appState.settings.selectedConnectorTypes, value: connector, isEnabled: isEnabled)
            }
        )
    }

    private func updateSelection<T: Equatable>(_ collection: inout [T], value: T, isEnabled: Bool) {
        if isEnabled {
            if !collection.contains(value) {
                collection.append(value)
            }
        } else if collection.count > 1 {
            collection.removeAll { $0 == value }
        }
    }

    private func calculateRoute() async {
        guard let origin = selectedOrigin, let destination = selectedDestination else { return }
        await appState.planTrip(origin: origin, destination: destination, waypoints: waypoints)
    }

    private func useCurrentLocationAsOrigin() async {
        do {
            let coordinate = try await locationManager.requestCurrentCoordinate()
            selectedOrigin = TripPlace(name: "Ma position actuelle", coordinate: coordinate)
        } catch {
            selectionError = AppError.from(error)
        }
    }

    private func restoreInitialPlacesIfNeeded() {
        guard selectedOrigin == nil, selectedDestination == nil else { return }
        if let latestTrip = appState.routeHistory.first {
            selectedOrigin = latestTrip.origin
            selectedDestination = latestTrip.destination
            waypoints = latestTrip.waypoints
        }
    }

    private func samePlace(_ lhs: TripPlace, _ rhs: TripPlace) -> Bool {
        abs(lhs.latitude - rhs.latitude) < 0.0001
        && abs(lhs.longitude - rhs.longitude) < 0.0001
    }

    private func moveWaypoint(at index: Int, offset: Int) {
        let target = index + offset
        guard waypoints.indices.contains(index), waypoints.indices.contains(target) else { return }
        waypoints.swapAt(index, target)
    }

    private func removeWaypoint(at index: Int) {
        guard waypoints.indices.contains(index) else { return }
        waypoints.remove(at: index)
    }

    private func applySelection(_ place: TripPlace, for target: LocationPickerTarget) {
        switch target {
        case .origin:
            selectedOrigin = place
        case .destination:
            selectedDestination = place
        case .newWaypoint:
            waypoints.append(place)
        case .waypoint(let waypointID):
            guard let index = waypoints.firstIndex(where: { $0.id == waypointID }) else { return }
            let existingID = waypoints[index].id
            waypoints[index] = TripPlace(id: existingID, name: place.name, coordinate: place.coordinate)
        }
    }

    private func fitMapToContent() {
        let coordinates = mapPoints.map(\.coordinate) + (appState.currentRoute?.path.map(\.coordinate) ?? [])
        guard !coordinates.isEmpty else {
            detailMapPosition = .region(plannerDefaultRegion)
            return
        }

        detailMapPosition = .rect(MKMapRect.boundingRect(for: coordinates))
    }
}

private struct LocationPickerContext: Identifiable {
    let id = UUID()
    let target: LocationPickerTarget
}

private enum LocationPickerTarget: Equatable {
    case origin
    case destination
    case newWaypoint
    case waypoint(UUID)

    var title: String {
        switch self {
        case .origin:
            return "Choisir le départ"
        case .destination:
            return "Choisir la destination"
        case .newWaypoint:
            return "Ajouter une étape"
        case .waypoint:
            return "Modifier une étape"
        }
    }
}

private struct PlannerMapPoint: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D
    let tint: Color
    let symbol: String
}

private struct LocationPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let recentPlaces: [TripPlace]
    let allowsCurrentLocation: Bool
    @ObservedObject var locationManager: PlannerLocationManager
    let onSelect: (TripPlace) -> Void

    @StateObject private var searchService = LocationSearchService()
    @State private var searchText: String = ""
    @State private var mapPosition: MapCameraPosition = .region(plannerDefaultRegion)
    @State private var mapCenter = plannerDefaultRegion.center
    @State private var isResolvingSelection = false
    @State private var localError: AppError?

    var body: some View {
        NavigationStack {
            List {
                if allowsCurrentLocation {
                    Section("Position actuelle") {
                        Button {
                            Task { await pickCurrentLocation() }
                        } label: {
                            Label("Utiliser ma position GPS actuelle", systemImage: "location.fill")
                        }
                    }
                }

                Section("Carte") {
                    ZStack {
                        Map(position: $mapPosition) {
                            Annotation("Point sélectionné", coordinate: mapCenter) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.title)
                                    .foregroundStyle(.red)
                            }
                        }
                        .frame(height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .onMapCameraChange(frequency: .continuous) { context in
                            mapCenter = context.region.center
                        }
                    }

                    Button {
                        Task { await pickMapCenter() }
                    } label: {
                        if isResolvingSelection {
                            HStack {
                                ProgressView()
                                Text("Validation du point…")
                            }
                        } else {
                            Label("Choisir le point au centre de la carte", systemImage: "mappin.and.ellipse")
                        }
                    }
                    .disabled(isResolvingSelection)
                }

                if !recentPlaces.isEmpty {
                    Section("Récents") {
                        ForEach(recentPlaces) { place in
                            Button(place.name) {
                                onSelect(place)
                                dismiss()
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }

                if !searchService.completions.isEmpty {
                    Section("Résultats") {
                        ForEach(searchService.completions) { completion in
                            Button {
                                Task { await pickCompletion(completion) }
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(completion.title)
                                    if !completion.subtitle.isEmpty {
                                        Text(completion.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Rechercher un lieu")
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                }
            }
            .alert("Sélection impossible", isPresented: Binding(
                get: { localError != nil },
                set: { if !$0 { localError = nil } }
            )) {
                Button("OK") { localError = nil }
            } message: {
                Text(localError?.message ?? "")
            }
            .onChange(of: searchText) { _, newValue in
                searchService.update(query: newValue)
            }
        }
    }

    private func pickCurrentLocation() async {
        do {
            let coordinate = try await locationManager.requestCurrentCoordinate()
            onSelect(TripPlace(name: "Ma position actuelle", coordinate: coordinate))
            dismiss()
        } catch {
            localError = AppError.from(error)
        }
    }

    private func pickCompletion(_ completion: LocationSearchCompletion) async {
        isResolvingSelection = true
        defer { isResolvingSelection = false }

        do {
            let place = try await searchService.resolve(completion: completion)
            onSelect(place)
            dismiss()
        } catch {
            localError = AppError.from(error)
        }
    }

    private func pickMapCenter() async {
        isResolvingSelection = true
        defer { isResolvingSelection = false }

        do {
            let name = try await reverseGeocodedName(for: mapCenter)
            onSelect(TripPlace(name: name, coordinate: mapCenter))
            dismiss()
        } catch {
            localError = AppError.from(error)
        }
    }

    private func reverseGeocodedName(for coordinate: CLLocationCoordinate2D) async throws -> String {
        let geocoder = CLGeocoder()
        let placemarks = try await geocoder.reverseGeocodeLocation(
            CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        )

        if let placemark = placemarks.first {
            let components = [
                placemark.name,
                placemark.locality,
                placemark.administrativeArea
            ]
            .compactMap { $0 }
            .filter { !$0.isEmpty }

            if !components.isEmpty {
                return components.joined(separator: ", ")
            }
        }

        return String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude)
    }
}

@MainActor
private final class PlannerLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D, Error>?
    private var authorizationContinuation: CheckedContinuation<Void, Error>?

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
    }

    func requestCurrentCoordinate() async throws -> CLLocationCoordinate2D {
        if authorizationStatus == .notDetermined {
            try await requestAuthorizationIfNeeded()
        }

        guard authorizationStatus != .denied, authorizationStatus != .restricted else {
            throw NSError(
                domain: "PlannerLocationManager",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "L’accès à la position GPS est refusé."]
            )
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            manager.requestLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            authorizationContinuation?.resume(returning: ())
            authorizationContinuation = nil
        case .denied, .restricted:
            authorizationContinuation?.resume(
                throwing: NSError(
                    domain: "PlannerLocationManager",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "L’accès à la position GPS est refusé."]
                )
            )
            authorizationContinuation = nil
        case .notDetermined:
            break
        @unknown default:
            authorizationContinuation?.resume(returning: ())
            authorizationContinuation = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else {
            continuation?.resume(
                throwing: NSError(
                    domain: "PlannerLocationManager",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Position GPS indisponible."]
                )
            )
            continuation = nil
            return
        }

        continuation?.resume(returning: coordinate)
        continuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    private func requestAuthorizationIfNeeded() async throws {
        guard authorizationStatus == .notDetermined else { return }

        try await withCheckedThrowingContinuation { continuation in
            authorizationContinuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }
}

private struct LocationSearchCompletion: Identifiable {
    let id = UUID()
    let completion: MKLocalSearchCompletion

    var title: String { completion.title }
    var subtitle: String { completion.subtitle }
}

@MainActor
private final class LocationSearchService: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published private(set) var completions: [LocationSearchCompletion] = []

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func update(query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        completer.queryFragment = trimmedQuery
        if trimmedQuery.isEmpty {
            completions = []
        }
    }

    func resolve(completion: LocationSearchCompletion) async throws -> TripPlace {
        let request = MKLocalSearch.Request(completion: completion.completion)
        let response = try await MKLocalSearch(request: request).start()
        guard let item = response.mapItems.first else {
            throw RoutingError.noRouteFound
        }

        let coordinate = item.placemark.coordinate
        let name = [item.name, item.placemark.title]
            .compactMap { $0 }
            .first(where: { !$0.isEmpty })
            ?? String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude)

        return TripPlace(name: name, coordinate: coordinate)
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        completions = completer.results.prefix(8).map(LocationSearchCompletion.init)
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        completions = []
    }
}

private extension MKMapRect {
    static func boundingRect(for coordinates: [CLLocationCoordinate2D]) -> MKMapRect {
        coordinates.reduce(.null) { partialResult, coordinate in
            let point = MKMapPoint(coordinate)
            let rect = MKMapRect(
                origin: point,
                size: MKMapSize(width: 1_000, height: 1_000)
            )
            return partialResult.isNull ? rect : partialResult.union(rect)
        }
    }
}
