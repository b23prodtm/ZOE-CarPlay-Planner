import Foundation
import CoreLocation

// MARK: - ChargingPlannerInput

struct ChargingPlannerInput: Sendable {
    let currentSOCPercent: Double
    let usableBatteryKWh: Double
    let consumptionWhPerKm: Double
    let distanceKm: Double
    let strategy: ChargingStrategy
    let chargingPowerKW: Double
    let availableStations: [ChargingStation]
    let roadTypes: RoadTypeDistribution
    let preferHighwayStations: Bool
    let stationSelectionPreference: ChargingStationSelectionPreference
}

enum ChargingStationSelectionPreference: String, CaseIterable, Sendable {
    case earlier
    case balanced
    case later

    var label: String {
        switch self {
        case .earlier:
            return "Plus tôt"
        case .balanced:
            return "Standard"
        case .later:
            return "Plus tard"
        }
    }
}

// MARK: - ChargingPlanner

/// Moteur de planification de recharge — indépendant de l'interface.
/// Entrée : paramètres du trajet. Sortie : ChargingPlan.
struct ChargingPlanner: Sendable {

    func plan(input: ChargingPlannerInput) -> ChargingPlan {
        let effectiveConsumption = EnergyConsumptionModel.weightedConsumption(
            roadTypes: input.roadTypes,
            overrideWhPerKm: input.consumptionWhPerKm
        )

        var stops: [ChargingStop] = []
        var remainingSOC = input.currentSOCPercent
        var traveledKm = 0.0

        while traveledKm < input.distanceKm {
            let remainingDistance = input.distanceKm - traveledKm
            let energyAvailable = (remainingSOC / 100.0) * input.usableBatteryKWh
            _ = energyAvailable / (effectiveConsumption / 1000.0)

            // Distance maximale avant d'atteindre le seuil de déclenchement
            let energyAtTrigger = (input.strategy.triggerSOCPercent / 100.0) * input.usableBatteryKWh
            let rangeAtTrigger = (energyAvailable - energyAtTrigger) / (effectiveConsumption / 1000.0)

            if rangeAtTrigger >= remainingDistance {
                // On arrive sans recharger
                let energyUsed = EnergyConsumptionModel.energyKWh(
                    distanceKm: remainingDistance,
                    consumptionWhPerKm: effectiveConsumption
                )
                let socUsed = (energyUsed / input.usableBatteryKWh) * 100.0
                remainingSOC = max(0, remainingSOC - socUsed)
                break
            }

            // Recharge nécessaire
            let stopDistanceFromHere = max(0, rangeAtTrigger)
            let distanceAtStop = traveledKm + stopDistanceFromHere

            let energyUsedToStop = EnergyConsumptionModel.energyKWh(
                distanceKm: stopDistanceFromHere,
                consumptionWhPerKm: effectiveConsumption
            )
            let socAtStop = max(0, remainingSOC - (energyUsedToStop / input.usableBatteryKWh) * 100.0)

            let energyToAdd = ((input.strategy.targetSOCPercent - socAtStop) / 100.0) * input.usableBatteryKWh
            let chargeDurationMin = (energyToAdd / input.chargingPowerKW) * 60.0

            let station = bestStation(
                near: distanceAtStop,
                stations: input.availableStations,
                preferHighwayStations: input.preferHighwayStations,
                selectionPreference: input.stationSelectionPreference
            )

            let stop = ChargingStop(
                id: UUID(),
                distanceFromOriginKm: distanceAtStop,
                socOnArrivalPercent: socAtStop,
                socAfterChargePercent: input.strategy.targetSOCPercent,
                energyToAddKWh: max(0, energyToAdd),
                estimatedChargeDurationMinutes: max(0, chargeDurationMin),
                station: station
            )
            stops.append(stop)

            remainingSOC = input.strategy.targetSOCPercent
            traveledKm = distanceAtStop

            // Sécurité : éviter une boucle infinie
            if stops.count > 20 { break }
        }

        // SOC final estimé
        let totalEnergyKWh = EnergyConsumptionModel.energyKWh(
            distanceKm: input.distanceKm,
            consumptionWhPerKm: effectiveConsumption
        )
        let totalEnergySoc = (totalEnergyKWh / input.usableBatteryKWh) * 100.0
        let rechargedSoc = stops.reduce(0.0) { $0 + ($1.socAfterChargePercent - $1.socOnArrivalPercent) }
        let arrivalSOC = max(0, input.currentSOCPercent - totalEnergySoc + rechargedSoc)

        let totalExtraTime = stops.reduce(0.0) { $0 + $1.estimatedChargeDurationMinutes }

        return ChargingPlan(
            stops: stops,
            estimatedArrivalSOCPercent: min(100, arrivalSOC),
            totalExtraTimeMinutes: totalExtraTime
        )
    }

    // MARK: - Private

    private func bestStation(
        near distanceKm: Double,
        stations: [ChargingStation],
        preferHighwayStations: Bool,
        selectionPreference: ChargingStationSelectionPreference
    ) -> ChargingStation? {
        // Priorité aux bornes proches de la distance cible, dans un rayon de 20 km
        stations
            .filter { abs($0.distanceFromRouteKm - distanceKm) < 20 }
            .sorted {
                compareStations(
                    lhs: $0,
                    rhs: $1,
                    targetDistance: distanceKm,
                    preferHighwayStations: preferHighwayStations,
                    selectionPreference: selectionPreference
                )
            }
            .first
    }

    private func compareStations(
        lhs: ChargingStation,
        rhs: ChargingStation,
        targetDistance: Double,
        preferHighwayStations: Bool,
        selectionPreference: ChargingStationSelectionPreference
    ) -> Bool {
        let lhsDelta = lhs.distanceFromRouteKm - targetDistance
        let rhsDelta = rhs.distanceFromRouteKm - targetDistance

        switch selectionPreference {
        case .earlier:
            let lhsEarlier = lhsDelta <= 0
            let rhsEarlier = rhsDelta <= 0
            if lhsEarlier != rhsEarlier { return lhsEarlier }
            if abs(lhsDelta) != abs(rhsDelta) { return abs(lhsDelta) < abs(rhsDelta) }
        case .later:
            let lhsLater = lhsDelta >= 0
            let rhsLater = rhsDelta >= 0
            if lhsLater != rhsLater { return lhsLater }
            if abs(lhsDelta) != abs(rhsDelta) { return abs(lhsDelta) < abs(rhsDelta) }
        case .balanced:
            if abs(lhsDelta) != abs(rhsDelta) { return abs(lhsDelta) < abs(rhsDelta) }
        }

        if preferHighwayStations, lhs.isHighway != rhs.isHighway {
            return lhs.isHighway == true
        }

        if lhs.maxPowerKW != rhs.maxPowerKW {
            return lhs.maxPowerKW > rhs.maxPowerKW
        }

        return lhs.distanceFromRouteKm < rhs.distanceFromRouteKm
    }
}
