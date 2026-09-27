import Foundation
import CoreLocation
import Combine

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

    // MARK: - Init

    init() {
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
    func disconnectRenault() {
        auth.clearCredentials()
        realService = nil
        settings.useSimulationMode = true
        settings.save()
        isAuthenticated = false
    }

    // MARK: - Vehicle

    func refreshVehicleStatus() async {
        isLoading = true
        defer { isLoading = false }
        do {
            vehicleStatus = try await activeVehicleService.getVehicleStatus()
        } catch {
            self.error = AppError.from(error)
        }
    }

    // MARK: - Planning

    func planRoute(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) async {
        isLoading = true
        defer { isLoading = false }
        error = nil
        do {
            let route = try await routingProvider.calculateRoute(from: origin, to: destination)
            currentRoute = route

            let stations = try await stationProvider.findStations(
                along: route,
                connectorTypes: settings.vehicle.connectorTypes
            )

            guard let status = vehicleStatus else { return }
            let input = ChargingPlannerInput(
                currentSOCPercent: status.battery.stateOfChargePercent,
                usableBatteryKWh: settings.vehicle.usableBatteryKWh,
                consumptionWhPerKm: settings.consumptionWhPerKm,
                distanceKm: route.totalDistanceKm,
                strategy: ChargingStrategy(
                    minimumSOCPercent: settings.minBatteryAtArrivalPercent,
                    targetSOCPercent: settings.maxBatteryAfterChargePercent,
                    safetyMarginPercent: settings.safetyMarginPercent
                ),
                chargingPowerKW: settings.preferredChargingPowerKW,
                availableStations: stations,
                roadTypes: route.roadType
            )
            chargingPlan = chargingPlanner.plan(input: input)
        } catch {
            self.error = AppError.from(error)
        }
    }

    // MARK: - Private

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
}
