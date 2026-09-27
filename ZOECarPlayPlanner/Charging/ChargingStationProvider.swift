import Foundation
import CoreLocation

// MARK: - ChargingStationProvider Protocol

protocol ChargingStationProvider: Sendable {
    func findStations(
        along route: Route,
        connectorTypes: [ConnectorType],
        networks: [ChargingNetwork]
    ) async throws -> [ChargingStation]
}

// MARK: - MockChargingStationProvider

/// Fournisseur de bornes simulé — fonctionne sans API externe.
struct MockChargingStationProvider: ChargingStationProvider {

    func findStations(
        along route: Route,
        connectorTypes: [ConnectorType],
        networks: [ChargingNetwork]
    ) async throws -> [ChargingStation] {
        // Générer des bornes fictives tous les ~80 km sur le trajet.
        // Si l'utilisateur n'évite pas les autoroutes, privilégier des aires d'autoroute.
        var stations: [ChargingStation] = []
        let totalKm = route.totalDistanceKm
        var distanceMark = 80.0
        let preferHighwayNetwork = !route.routePreferences.avoidHighways
        let availableNetworks: [ChargingNetwork] = preferHighwayNetwork
            ? [.ionity, .electra, .totalEnergies, .fastned]
            : [.electra, .totalEnergies, .allego, .local]

        while distanceMark < totalKm {
            let fraction = distanceMark / totalKm
            let lat = route.origin.coordinate.latitude
                    + fraction * (route.destination.coordinate.latitude - route.origin.coordinate.latitude)
            let lon = route.origin.coordinate.longitude
                    + fraction * (route.destination.coordinate.longitude - route.origin.coordinate.longitude)

            let network = availableNetworks[stations.count % availableNetworks.count]
            let stationName = preferHighwayNetwork
                ? "Aire autoroute \(network.displayName) #\(stations.count + 1)"
                : "Borne \(network.displayName) #\(stations.count + 1)"

            let station = ChargingStation(
                id: UUID(),
                name: stationName,
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                network: network,
                connectors: [
                    StationConnector(id: UUID(), type: .type2AC, powerKW: 22, isAvailable: true),
                    StationConnector(id: UUID(), type: .ccs, powerKW: 150, isAvailable: true)
                ],
                isAvailable: true,
                distanceFromRouteKm: distanceMark,
                isHighway: preferHighwayNetwork
            )
            let networkMatches = networks.isEmpty || networks.contains(station.network)
            let connectorMatches = connectorTypes.isEmpty || station.connectors.contains { connectorTypes.contains($0.type) }
            if networkMatches && connectorMatches {
                stations.append(station)
            }
            distanceMark += 80
        }
        return stations
    }
}
