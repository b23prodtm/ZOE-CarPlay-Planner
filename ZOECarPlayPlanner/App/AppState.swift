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

    // MARK: - Published State
    @Published var settings: PlannerSettings = PlannerSettings.load()
    @Published var vehicleStatus: VehicleStatus?
    @Published var chargingPlan: ChargingPlan?
    @Published var currentRoute: Route?
    @Published var isLoading: Bool = false
    @Published var error: AppError?

    // MARK: - Init
    init() {
        Task { await refreshVehicleStatus() }
    }

    // MARK: - Vehicle

    func refreshVehicleStatus() async {
        isLoading = true
        defer { isLoading = false }
        do {
            vehicleStatus = try await mockVehicleService.getVehicleStatus()
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
}
