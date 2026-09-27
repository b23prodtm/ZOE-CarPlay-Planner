import Foundation
import CoreLocation

// MARK: - ChargingStationProvider Protocol

protocol ChargingStationProvider: Sendable {
    func findStations(
        along route: Route,
        connectorTypes: [ConnectorType]
    ) async throws -> [ChargingStation]
}

// MARK: - MockChargingStationProvider

/// Fournisseur de bornes simulé — fonctionne sans API externe.
struct MockChargingStationProvider: ChargingStationProvider {

    func findStations(
        along route: Route,
        connectorTypes: [ConnectorType]
    ) async throws -> [ChargingStation] {
        // Générer des bornes fictives tous les ~80 km sur le trajet.
        // Si l'utilisateur n'évite pas les autoroutes, privilégier des aires d'autoroute.
        var stations: [ChargingStation] = []
        let totalKm = route.totalDistanceKm
        var distanceMark = 80.0
        let preferHighwayNetwork = !route.routePreferences.avoidHighways

        while distanceMark < totalKm {
            let fraction = distanceMark / totalKm
            let lat = route.origin.coordinate.latitude
                    + fraction * (route.destination.coordinate.latitude - route.origin.coordinate.latitude)
            let lon = route.origin.coordinate.longitude
                    + fraction * (route.destination.coordinate.longitude - route.origin.coordinate.longitude)

            let stationName: String
            let operatorName: String
            if preferHighwayNetwork {
                stationName = "Aire autoroute Ionity #\(stations.count + 1)"
                operatorName = "Ionity Autoroute"
            } else {
                stationName = "Borne urbaine #\(stations.count + 1)"
                operatorName = "Réseau local"
            }

            let station = ChargingStation(
                id: UUID(),
                name: stationName,
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                operatorName: operatorName,
                connectors: [
                    StationConnector(id: UUID(), type: .type2AC, powerKW: 22, isAvailable: true),
                    StationConnector(id: UUID(), type: .ccs, powerKW: 150, isAvailable: true)
                ],
                isAvailable: true,
                distanceFromRouteKm: distanceMark,
                isHighway: preferHighwayNetwork
            )
            stations.append(station)
            distanceMark += 80
        }
        return stations
    }
}
