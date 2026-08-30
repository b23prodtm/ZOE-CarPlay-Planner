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
        // Générer des bornes fictives tous les ~80 km sur le trajet
        var stations: [ChargingStation] = []
        let totalKm = route.totalDistanceKm
        var distanceMark = 80.0

        while distanceMark < totalKm {
            let fraction = distanceMark / totalKm
            let lat = route.origin.coordinate.latitude
                    + fraction * (route.destination.coordinate.latitude - route.origin.coordinate.latitude)
            let lon = route.origin.coordinate.longitude
                    + fraction * (route.destination.coordinate.longitude - route.origin.coordinate.longitude)

            let station = ChargingStation(
                id: UUID(),
                name: "Borne Ionity #\(stations.count + 1)",
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                operatorName: "Ionity",
                connectors: [
                    StationConnector(id: UUID(), type: .type2AC, powerKW: 22, isAvailable: true),
                    StationConnector(id: UUID(), type: .ccs, powerKW: 150, isAvailable: true)
                ],
                isAvailable: true,
                distanceFromRouteKm: distanceMark
            )
            stations.append(station)
            distanceMark += 80
        }
        return stations
    }
}
