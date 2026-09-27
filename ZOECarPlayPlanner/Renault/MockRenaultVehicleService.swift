import Foundation
import CoreLocation

// MARK: - SimulationScenario

/// Scénarios de simulation disponibles.
enum SimulationScenario: String, CaseIterable, Identifiable, Sendable {
    case full = "Batterie 100 %"
    case high = "Batterie 80 %"
    case half = "Batterie 50 %"
    case low = "Batterie 20 %"
    case charging = "Véhicule en charge"
    case disconnected = "Véhicule non connecté"

    var id: String { rawValue }

    var socPercent: Double {
        switch self {
        case .full:         return 100
        case .high:         return 80
        case .half:         return 50
        case .low:          return 20
        case .charging:     return 45
        case .disconnected: return 62
        }
    }

    var chargingStatus: ChargingStatus {
        switch self {
        case .charging:     return .charging
        case .disconnected: return .notConnected
        default:            return .connected
        }
    }
}

// MARK: - MockRenaultVehicleService

/// Service de simulation — fonctionne sans compte Renault.
actor MockRenaultVehicleService: RenaultVehicleService {
    private let vehicle: Vehicle
    private var scenario: SimulationScenario
    private var customSOCPercent: Double?

    init(vehicle: Vehicle = .defaultZOE, scenario: SimulationScenario = .high) {
        self.vehicle = vehicle
        self.scenario = scenario
    }

    func setScenario(_ newScenario: SimulationScenario) {
        scenario = newScenario
        customSOCPercent = nil
    }

    func setCustomSOC(_ soc: Double) {
        customSOCPercent = min(100, max(0, soc))
    }

    // MARK: RenaultVehicleService

    func getVehicleStatus() async throws -> VehicleStatus {
        try await simulateDelay()
        let battery = try await getBatteryState()
        let charging = try await getChargingStatus()
        return VehicleStatus(
            battery: battery,
            charging: charging,
            odometer: 24_350,
            isReachable: scenario != .disconnected,
            lastSeen: Date()
        )
    }

    func getBatteryState() async throws -> BatteryState {
        try await simulateDelay()
        let soc = customSOCPercent ?? scenario.socPercent
        let rangeKm = (soc / 100.0) * 298.0  // ≈ 298 km à 100 %
        return BatteryState(
            stateOfChargePercent: soc,
            estimatedRangeKm: rangeKm,
            isCharging: scenario == .charging,
            chargingPowerKW: scenario == .charging ? 7.4 : nil,
            targetChargePercent: scenario == .charging ? 80 : nil,
            lastUpdated: Date()
        )
    }

    func getVehicleLocation() async throws -> CLLocationCoordinate2D? {
        try await simulateDelay()
        guard scenario != .disconnected else { return nil }
        // Lyon par défaut
        return CLLocationCoordinate2D(latitude: 45.7640, longitude: 4.8357)
    }

    func getChargingStatus() async throws -> ChargingStatus {
        try await simulateDelay()
        return scenario.chargingStatus
    }

    // MARK: Private

    private func simulateDelay() async throws {
        try await Task.sleep(nanoseconds: 300_000_000)  // 0.3 s
    }
}
