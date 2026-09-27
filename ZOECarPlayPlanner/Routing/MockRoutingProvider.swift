import Foundation
import CoreLocation

// MARK: - MockRoutingProvider

/// Fournisseur de routage simulé — fonctionne sans clé API ni réseau.
struct MockRoutingProvider: RoutingProvider {
    func calculateRoute(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        preferences: RoutePreferences
    ) async throws -> Route {
        var distanceKm = haversineDistanceKm(from: origin, to: destination) * 1.3

        if preferences.avoidHighways {
            distanceKm *= 1.15
        } else if preferences.preferHighways {
            distanceKm *= 0.95
        }

        if preferences.avoidTolls {
            distanceKm *= 1.05
        }

        if preferences.preferScenic {
            distanceKm *= 1.08
        }

        let averageSpeedKmh: Double = preferences.mode == .eco ? 72.0 : 90.0
        let durationMinutes = distanceKm / averageSpeedKmh * 60.0

        return Route(
            origin: RoutePoint(
                name: "Départ",
                coordinate: origin,
                distanceFromOriginKm: 0
            ),
            destination: RoutePoint(
                name: "Destination",
                coordinate: destination,
                distanceFromOriginKm: distanceKm
            ),
            totalDistanceKm: distanceKm,
            estimatedDurationMinutes: durationMinutes,
            waypoints: [],
            roadType: .typical,
            routePreferences: preferences
        )
    }

    func calculateRoute(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) async throws -> Route {
        try await calculateRoute(from: origin, to: destination, preferences: .init())
    }

    // MARK: - Haversine

    private func haversineDistanceKm(
        from a: CLLocationCoordinate2D,
        to b: CLLocationCoordinate2D
    ) -> Double {
        let R = 6371.0
        let dLat = (b.latitude - a.latitude).toRadians
        let dLon = (b.longitude - a.longitude).toRadians
        let lat1 = a.latitude.toRadians
        let lat2 = b.latitude.toRadians

        let x = sin(dLat / 2) * sin(dLat / 2)
             + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(x), sqrt(1 - x))
        return R * c
    }
}

private extension Double {
    var toRadians: Double { self * .pi / 180 }
}
