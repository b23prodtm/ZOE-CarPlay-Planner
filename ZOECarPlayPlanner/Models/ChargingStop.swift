import Foundation
import CoreLocation

// MARK: - ChargingStop

/// Un arrêt recharge planifié sur le trajet.
struct ChargingStop: Identifiable, Sendable {
    let id: UUID
    /// Distance depuis le départ (km)
    let distanceFromOriginKm: Double
    /// SOC estimé à l'arrivée à cet arrêt (%)
    let socOnArrivalPercent: Double
    /// SOC cible après recharge (%)
    let socAfterChargePercent: Double
    /// Énergie à récupérer (kWh)
    let energyToAddKWh: Double
    /// Durée estimée de recharge (minutes)
    let estimatedChargeDurationMinutes: Double
    /// Borne recommandée si disponible
    let station: ChargingStation?

    var displayArrivalSOC: String { "\(Int(socOnArrivalPercent)) %" }
    var displayTargetSOC: String { "\(Int(socAfterChargePercent)) %" }
    var displayDuration: String { "≈ \(Int(estimatedChargeDurationMinutes)) min" }
}

// MARK: - ChargingPlan

/// Plan de recharge complet pour un trajet.
struct ChargingPlan: Sendable {
    let stops: [ChargingStop]
    let estimatedArrivalSOCPercent: Double
    let totalExtraTimeMinutes: Double

    var numberOfStops: Int { stops.count }
    var requiresCharging: Bool { !stops.isEmpty }

    var displayArrivalSOC: String { "\(Int(estimatedArrivalSOCPercent)) %" }

    var summary: String {
        if stops.isEmpty {
            return "Aucune recharge nécessaire"
        }
        return "\(stops.count) recharge\(stops.count > 1 ? "s" : "") prévue\(stops.count > 1 ? "s" : "")"
    }
}
