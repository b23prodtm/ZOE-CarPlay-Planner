import Foundation

// MARK: - BatteryState

/// État de la batterie à un instant donné.
struct BatteryState: Codable, Sendable {
    /// Pourcentage de charge (0–100)
    var stateOfChargePercent: Double
    /// Autonomie estimée en kilomètres
    var estimatedRangeKm: Double
    /// Indique si le véhicule est en charge
    var isCharging: Bool
    /// Puissance de charge actuelle (kW), nil si non disponible
    var chargingPowerKW: Double?
    /// Niveau cible de charge (%)
    var targetChargePercent: Int?
    /// Date de la dernière mise à jour
    var lastUpdated: Date

    var stateOfChargeDecimal: Double {
        stateOfChargePercent / 100.0
    }

    var displayPercent: String {
        "\(Int(stateOfChargePercent)) %"
    }
}

// MARK: - ChargingStatus

enum ChargingStatus: String, Codable, Sendable {
    case notConnected = "Non connecté"
    case connected = "Connecté"
    case charging = "En charge"
    case chargeComplete = "Charge terminée"
    case error = "Erreur"

    var displayName: String { rawValue }
    var isActive: Bool { self == .charging }
}

// MARK: - VehicleStatus

/// Agrégat de l'état complet du véhicule.
struct VehicleStatus: Sendable {
    var battery: BatteryState
    var charging: ChargingStatus
    var odometer: Double?       // km
    var isReachable: Bool
    var lastSeen: Date
}
