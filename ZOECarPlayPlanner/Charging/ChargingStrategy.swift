import Foundation

// MARK: - ChargingStrategy

/// Stratégie de recharge : quand et jusqu'où recharger.
struct ChargingStrategy: Sendable {
    /// SOC minimum toléré avant de chercher une borne (%)
    var minimumSOCPercent: Double
    /// SOC cible après recharge (%)
    var targetSOCPercent: Double
    /// Marge de sécurité supplémentaire (%)
    var safetyMarginPercent: Double

    /// SOC effectif de déclenchement de recharge en tenant compte de la marge.
    var triggerSOCPercent: Double {
        minimumSOCPercent + safetyMarginPercent
    }

    static let `default` = ChargingStrategy(
        minimumSOCPercent: 15,
        targetSOCPercent: 80,
        safetyMarginPercent: 10
    )
}
