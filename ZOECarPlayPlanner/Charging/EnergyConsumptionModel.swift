import Foundation

// MARK: - EnergyConsumptionModel

/// Modèle de consommation énergétique pour la ZOE.
/// Les valeurs sont des estimations — toujours afficher comme telles.
struct EnergyConsumptionModel: Sendable {

    // MARK: - Consommation par type de route (Wh/km)

    struct RoadConsumption: Sendable {
        var highwayWhPerKm: Double  // Autoroute
        var roadWhPerKm: Double     // Route
        var cityWhPerKm: Double     // Ville
    }

    static let zoeZE50Default = RoadConsumption(
        highwayWhPerKm: 200,  // 185–220 Wh/km
        roadWhPerKm: 165,     // 150–180 Wh/km
        cityWhPerKm: 140      // 120–160 Wh/km
    )

    // MARK: - Calcul de consommation effective

    /// Consommation pondérée selon la distribution des types de route.
    static func weightedConsumption(
        roadTypes: RoadTypeDistribution,
        consumption: RoadConsumption = zoeZE50Default,
        overrideWhPerKm: Double? = nil
    ) -> Double {
        if let override = overrideWhPerKm { return override }
        return (roadTypes.highwayPercent / 100.0) * consumption.highwayWhPerKm
             + (roadTypes.roadPercent    / 100.0) * consumption.roadWhPerKm
             + (roadTypes.cityPercent    / 100.0) * consumption.cityWhPerKm
    }

    /// Énergie nécessaire en kWh pour parcourir `distanceKm`.
    static func energyKWh(distanceKm: Double, consumptionWhPerKm: Double) -> Double {
        distanceKm * consumptionWhPerKm / 1000.0
    }
}
