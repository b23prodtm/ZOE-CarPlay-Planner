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
        let routeCoordinates = sampledRouteCoordinates(for: route)
        var distanceMark = 80.0
        var generatedIndex = 0
        let preferHighwayNetwork = !route.routePreferences.avoidHighways
        let availableNetworks: [ChargingNetwork] = preferHighwayNetwork
            ? [.ionity, .electra, .totalEnergies, .fastned]
            : [.electra, .totalEnergies, .allego, .local]

        while distanceMark < totalKm {
            let fraction = distanceMark / totalKm
            let coordinate = coordinate(at: fraction, along: routeCoordinates)

            let network = availableNetworks[generatedIndex % availableNetworks.count]
            let stationName = preferHighwayNetwork
                ? "Aire autoroute \(network.displayName) #\(generatedIndex + 1)"
                : "Borne \(network.displayName) #\(generatedIndex + 1)"

            let station = ChargingStation(
                id: UUID(),
                name: stationName,
                coordinate: coordinate,
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
            generatedIndex += 1
            distanceMark += 80
        }
        return stations
    }

    private func sampledRouteCoordinates(for route: Route) -> [CLLocationCoordinate2D] {
        let pathCoordinates = route.path.map(\.coordinate)
        if pathCoordinates.count >= 2 {
            return pathCoordinates
        }
        return [route.origin.coordinate, route.destination.coordinate]
    }

    private func coordinate(
        at fraction: Double,
        along routeCoordinates: [CLLocationCoordinate2D]
    ) -> CLLocationCoordinate2D {
        guard routeCoordinates.count >= 2 else {
            return routeCoordinates.first ?? .init(latitude: 0, longitude: 0)
        }

        let clLocations = routeCoordinates.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }
        let segmentLengths = zip(clLocations, clLocations.dropFirst()).map { $0.distance(from: $1) }
        let totalLength = segmentLengths.reduce(0, +)
        guard totalLength > 0 else { return routeCoordinates.last! }

        let targetLength = totalLength * min(max(fraction, 0), 1)
        var traveledLength = 0.0

        for (index, segmentLength) in segmentLengths.enumerated() {
            let nextLength = traveledLength + segmentLength
            if targetLength <= nextLength {
                let segmentFraction = segmentLength == 0 ? 0 : (targetLength - traveledLength) / segmentLength
                return interpolatedCoordinate(
                    from: routeCoordinates[index],
                    to: routeCoordinates[index + 1],
                    fraction: segmentFraction
                )
            }
            traveledLength = nextLength
        }

        return routeCoordinates.last!
    }

    private func interpolatedCoordinate(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D,
        fraction: Double
    ) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: start.latitude + (end.latitude - start.latitude) * fraction,
            longitude: start.longitude + (end.longitude - start.longitude) * fraction
        )
    }
}
