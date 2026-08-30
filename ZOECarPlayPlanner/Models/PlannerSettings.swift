import Foundation

// MARK: - PlannerSettings

/// Réglages utilisateur persistants pour le planificateur.
final class PlannerSettings: ObservableObject, Codable {
    @Published var consumptionWhPerKm: Double
    @Published var minBatteryAtArrivalPercent: Double
    @Published var maxBatteryAfterChargePercent: Double
    @Published var safetyMarginPercent: Double
    @Published var preferredChargingPowerKW: Double
    @Published var useSimulationMode: Bool
    @Published var simulatedSOCPercent: Double
    @Published var vehicle: Vehicle

    init(
        consumptionWhPerKm: Double = 170,
        minBatteryAtArrivalPercent: Double = 15,
        maxBatteryAfterChargePercent: Double = 80,
        safetyMarginPercent: Double = 10,
        preferredChargingPowerKW: Double = 22,
        useSimulationMode: Bool = true,
        simulatedSOCPercent: Double = 82,
        vehicle: Vehicle = .defaultZOE
    ) {
        self.consumptionWhPerKm = consumptionWhPerKm
        self.minBatteryAtArrivalPercent = minBatteryAtArrivalPercent
        self.maxBatteryAfterChargePercent = maxBatteryAfterChargePercent
        self.safetyMarginPercent = safetyMarginPercent
        self.preferredChargingPowerKW = preferredChargingPowerKW
        self.useSimulationMode = useSimulationMode
        self.simulatedSOCPercent = simulatedSOCPercent
        self.vehicle = vehicle
    }

    // MARK: Codable

    enum CodingKeys: String, CodingKey {
        case consumptionWhPerKm, minBatteryAtArrivalPercent, maxBatteryAfterChargePercent
        case safetyMarginPercent, preferredChargingPowerKW, useSimulationMode
        case simulatedSOCPercent, vehicle
    }

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        consumptionWhPerKm = try c.decodeIfPresent(Double.self, forKey: .consumptionWhPerKm) ?? 170
        minBatteryAtArrivalPercent = try c.decodeIfPresent(Double.self, forKey: .minBatteryAtArrivalPercent) ?? 15
        maxBatteryAfterChargePercent = try c.decodeIfPresent(Double.self, forKey: .maxBatteryAfterChargePercent) ?? 80
        safetyMarginPercent = try c.decodeIfPresent(Double.self, forKey: .safetyMarginPercent) ?? 10
        preferredChargingPowerKW = try c.decodeIfPresent(Double.self, forKey: .preferredChargingPowerKW) ?? 22
        useSimulationMode = try c.decodeIfPresent(Bool.self, forKey: .useSimulationMode) ?? true
        simulatedSOCPercent = try c.decodeIfPresent(Double.self, forKey: .simulatedSOCPercent) ?? 82
        vehicle = try c.decodeIfPresent(Vehicle.self, forKey: .vehicle) ?? .defaultZOE
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(consumptionWhPerKm, forKey: .consumptionWhPerKm)
        try c.encode(minBatteryAtArrivalPercent, forKey: .minBatteryAtArrivalPercent)
        try c.encode(maxBatteryAfterChargePercent, forKey: .maxBatteryAfterChargePercent)
        try c.encode(safetyMarginPercent, forKey: .safetyMarginPercent)
        try c.encode(preferredChargingPowerKW, forKey: .preferredChargingPowerKW)
        try c.encode(useSimulationMode, forKey: .useSimulationMode)
        try c.encode(simulatedSOCPercent, forKey: .simulatedSOCPercent)
        try c.encode(vehicle, forKey: .vehicle)
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "PlannerSettings")
        }
    }

    static func load() -> PlannerSettings {
        guard let data = UserDefaults.standard.data(forKey: "PlannerSettings"),
              let settings = try? JSONDecoder().decode(PlannerSettings.self, from: data)
        else { return PlannerSettings() }
        return settings
    }
}
