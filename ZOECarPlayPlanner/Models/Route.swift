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
    let routePreferences: RoutePreferences

    var displayDistance: String {
        "\(Int(totalDistanceKm.rounded())) km"
    }

    init(
        origin: RoutePoint,
        destination: RoutePoint,
        totalDistanceKm: Double,
        estimatedDurationMinutes: Double,
        waypoints: [RoutePoint] = [],
        roadType: RoadTypeDistribution = .typical,
        routePreferences: RoutePreferences = .init()
    ) {
        self.origin = origin
        self.destination = destination
        self.totalDistanceKm = totalDistanceKm
        self.estimatedDurationMinutes = estimatedDurationMinutes
        self.waypoints = waypoints
        self.roadType = roadType
        self.routePreferences = routePreferences
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

// MARK: - RoutePreferences

struct RoutePreferences: Codable, Equatable, Sendable {
    var avoidHighways: Bool
    var avoidTolls: Bool
    var preferHighways: Bool
    var preferScenic: Bool

    init(
        avoidHighways: Bool = false,
        avoidTolls: Bool = false,
        preferHighways: Bool = false,
        preferScenic: Bool = false
    ) {
        self.avoidHighways = avoidHighways
        self.avoidTolls = avoidTolls
        self.preferHighways = preferHighways
        self.preferScenic = preferScenic
    }

    var summaryText: String {
        var items: [String] = []
        if avoidHighways { items.append("évite autoroutes") }
        if avoidTolls { items.append("évite péages") }
        if preferHighways { items.append("préférer autoroutes") }
        if preferScenic { items.append("scenic") }
        return items.isEmpty ? "standard" : items.joined(separator: ", ")
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
