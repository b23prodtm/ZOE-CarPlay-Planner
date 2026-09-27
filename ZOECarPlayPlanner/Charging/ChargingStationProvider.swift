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
    private let highwayStationPresets: [StationPreset] = [
        StationPreset(name: "Aire de Mâcon-Saint-Albain", network: .ionity, powerKW: 350),
        StationPreset(name: "Aire de Nemours", network: .electra, powerKW: 300),
        StationPreset(name: "Aire de Beaune-Tailly", network: .totalEnergies, powerKW: 175),
        StationPreset(name: "Aire de Reims-Champagne", network: .fastned, powerKW: 300),
        StationPreset(name: "Aire de la Vallée de la Somme", network: .ionity, powerKW: 350),
        StationPreset(name: "Aire de Lançon-de-Provence", network: .electra, powerKW: 300)
    ]

    private let localStationPresets: [StationPreset] = [
        StationPreset(name: "Borne Electra Centre-ville", network: .electra, powerKW: 150),
        StationPreset(name: "Borne TotalEnergies Gare", network: .totalEnergies, powerKW: 175),
        StationPreset(name: "Borne Allego Périphérie", network: .allego, powerKW: 100),
        StationPreset(name: "Borne Réseau local Parking", network: .local, powerKW: 50)
    ]

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
        let presets = preferHighwayNetwork ? highwayStationPresets : localStationPresets
        let candidateOffsets = preferHighwayNetwork ? [-7.5, 0.0, 7.5] : [-5.0, 4.0]

        while distanceMark < totalKm {
            for offsetIndex in candidateOffsets.indices {
                let candidateDistance = distanceMark + candidateOffsets[offsetIndex]
                guard candidateDistance > 25, candidateDistance < totalKm - 10 else { continue }

                let fraction = candidateDistance / totalKm
                let preset = presets[(generatedIndex + offsetIndex) % presets.count]
                let coordinate = offsetCoordinate(
                    base: coordinate(at: fraction, along: routeCoordinates),
                    along: routeCoordinates,
                    fraction: fraction,
                    lateralShiftDegrees: preferHighwayNetwork ? 0.0035 : 0.002
                )

                let station = ChargingStation(
                    id: UUID(),
                    name: preset.name,
                    coordinate: coordinate,
                    network: preset.network,
                    connectors: connectors(for: preset),
                    isAvailable: true,
                    distanceFromRouteKm: candidateDistance,
                    isHighway: preferHighwayNetwork
                )
                let networkMatches = networks.isEmpty || networks.contains(station.network)
                let connectorMatches = connectorTypes.isEmpty || station.connectors.contains { connectorTypes.contains($0.type) }
                if networkMatches && connectorMatches {
                    stations.append(station)
                }
            }
            generatedIndex += 1
            distanceMark += 80
        }
        return stations.sorted { $0.distanceFromRouteKm < $1.distanceFromRouteKm }
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

    private func offsetCoordinate(
        base: CLLocationCoordinate2D,
        along routeCoordinates: [CLLocationCoordinate2D],
        fraction: Double,
        lateralShiftDegrees: Double
    ) -> CLLocationCoordinate2D {
        guard routeCoordinates.count >= 2 else { return base }

        let segmentIndex = max(
            0,
            min(routeCoordinates.count - 2, Int(Double(routeCoordinates.count - 1) * fraction))
        )
        let start = routeCoordinates[segmentIndex]
        let end = routeCoordinates[segmentIndex + 1]
        let deltaLatitude = end.latitude - start.latitude
        let deltaLongitude = end.longitude - start.longitude
        let length = sqrt((deltaLatitude * deltaLatitude) + (deltaLongitude * deltaLongitude))
        guard length > 0 else { return base }

        let perpendicularLatitude = -(deltaLongitude / length) * lateralShiftDegrees
        let perpendicularLongitude = (deltaLatitude / length) * lateralShiftDegrees

        return CLLocationCoordinate2D(
            latitude: base.latitude + perpendicularLatitude,
            longitude: base.longitude + perpendicularLongitude
        )
    }

    private func connectors(for preset: StationPreset) -> [StationConnector] {
        [
            StationConnector(id: UUID(), type: .type2AC, powerKW: 22, isAvailable: true),
            StationConnector(id: UUID(), type: .ccs, powerKW: preset.powerKW, isAvailable: true)
        ]
    }
}

private struct StationPreset {
    let name: String
    let network: ChargingNetwork
    let powerKW: Double
}
