import Foundation
import CoreLocation
import MapKit

// MARK: - AppleRoutingProvider

/// Fournisseur de routage utilisant MapKit (MKDirections).
/// Priorité 1 — fonctionne sans clé API externe.
struct AppleRoutingProvider: RoutingProvider {

    func calculateRoute(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) async throws -> Route {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .automobile

        let directions = MKDirections(request: request)

        do {
            let response = try await directions.calculate()
            guard let mkRoute = response.routes.first else {
                throw RoutingError.noRouteFound
            }

            let distanceKm = mkRoute.distance / 1000.0
            let durationMin = mkRoute.expectedTravelTime / 60.0

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
                estimatedDurationMinutes: durationMin,
                waypoints: [],
                roadType: roadTypeDistribution(for: mkRoute)
            )
        } catch let error as RoutingError {
            throw error
        } catch {
            throw RoutingError.networkError(underlying: error)
        }
    }

    // MARK: - Estimation du type de route

    /// Estimation simplifiée basée sur la distance et la durée.
    private func roadTypeDistribution(for route: MKRoute) -> RoadTypeDistribution {
        let avgSpeedKmh = (route.distance / 1000.0) / (route.expectedTravelTime / 3600.0)
        if avgSpeedKmh > 90 {
            return RoadTypeDistribution(highwayPercent: 80, roadPercent: 15, cityPercent: 5)
        } else if avgSpeedKmh > 60 {
            return RoadTypeDistribution(highwayPercent: 40, roadPercent: 50, cityPercent: 10)
        } else {
            return RoadTypeDistribution(highwayPercent: 10, roadPercent: 30, cityPercent: 60)
        }
    }
}
