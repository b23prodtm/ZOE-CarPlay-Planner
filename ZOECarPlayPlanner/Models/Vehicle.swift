import Foundation
import CoreLocation

// MARK: - Vehicle

/// Représente une Renault ZOE ou tout véhicule électrique compatible.
struct Vehicle: Identifiable, Codable, Sendable {
    let id: UUID
    var name: String
    var model: String
    var batteryCapacityKWh: Double  // Capacité nominale
    var usableBatteryKWh: Double    // Capacité utilisable
    var defaultConsumptionWhPerKm: Double
    var maxChargingPowerAC: Double  // kW
    var maxChargingPowerDC: Double  // kW
    var connectorTypes: [ConnectorType]

    /// ZOE ZE50 R110 par défaut
    static let defaultZOE = Vehicle(
        id: UUID(),
        name: "Renault ZOE",
        model: "ZE50 R110",
        batteryCapacityKWh: 52.0,
        usableBatteryKWh: 50.0,
        defaultConsumptionWhPerKm: 170.0,
        maxChargingPowerAC: 22.0,
        maxChargingPowerDC: 0.0,  // ZOE ZE50 sans CCS par défaut
        connectorTypes: [.type2AC]
    )
}

// MARK: - ConnectorType

enum ConnectorType: String, Codable, CaseIterable, Sendable {
    case type2AC = "Type 2 AC"
    case ccs = "CCS"
    case chademo = "CHAdeMO"
    case domestique = "Domestique"

    var displayName: String { rawValue }
}
