import Foundation
import CoreLocation

// MARK: - Route

/// Représente un itinéraire calculé entre deux points.
struct Route: Sendable {
    let origin: RoutePoint
    let destination: RoutePoint
    let totalDistanceKm: Double
    let estimatedDurationMinutes: Double
    let waypoints: [RoutePoint]
    let roadType: RoadTypeDistribution

    var displayDistance: String {
        "\(Int(totalDistanceKm)) km"
    }
}

// MARK: - RoutePoint

/// Un point sur l'itinéraire.
struct RoutePoint: Identifiable, Sendable {
    let id: UUID
    let name: String
    let coordinate: CLLocationCoordinate2D
    let distanceFromOriginKm: Double

    init(id: UUID = UUID(), name: String, coordinate: CLLocationCoordinate2D, distanceFromOriginKm: Double = 0) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.distanceFromOriginKm = distanceFromOriginKm
    }
}

// MARK: - RoadTypeDistribution

/// Distribution approximative des types de route (pourcentages).
struct RoadTypeDistribution: Sendable {
    var highwayPercent: Double  // Autoroute
    var roadPercent: Double     // Route nationale/départementale
    var cityPercent: Double     // Ville

    static let typical = RoadTypeDistribution(highwayPercent: 60, roadPercent: 30, cityPercent: 10)
    static let allHighway = RoadTypeDistribution(highwayPercent: 100, roadPercent: 0, cityPercent: 0)
    static let allCity = RoadTypeDistribution(highwayPercent: 0, roadPercent: 0, cityPercent: 100)
}
