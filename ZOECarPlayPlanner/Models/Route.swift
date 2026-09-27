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

// MARK: - TripPlace

/// Lieu sélectionnable (départ, destination ou étape) stockable dans l'historique.
struct TripPlace: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var name: String
    var latitude: Double
    var longitude: Double

    init(id: UUID = UUID(), name: String, coordinate: CLLocationCoordinate2D) {
        self.id = id
        self.name = name
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - PlannedTrip

/// Itinéraire recherché par l'utilisateur, persisté pour l'historique.
struct PlannedTrip: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let origin: TripPlace
    let destination: TripPlace
    let waypoints: [TripPlace]
    let preferences: RoutePreferences
    let searchedAt: Date

    init(
        id: UUID = UUID(),
        origin: TripPlace,
        destination: TripPlace,
        waypoints: [TripPlace],
        preferences: RoutePreferences,
        searchedAt: Date = Date()
    ) {
        self.id = id
        self.origin = origin
        self.destination = destination
        self.waypoints = waypoints
        self.preferences = preferences
        self.searchedAt = searchedAt
    }

    var allPlaces: [TripPlace] {
        [origin] + waypoints + [destination]
    }

    var summary: String {
        let stepText = waypoints.isEmpty ? "direct" : "\(waypoints.count) étape\(waypoints.count > 1 ? "s" : "")"
        return "\(origin.name) → \(destination.name) (\(stepText))"
    }
}

// MARK: - RoutePreferences

enum TravelMode: String, Codable, CaseIterable, Sendable {
    case normal
    case eco

    var label: String {
        switch self {
        case .normal: return "Normal"
        case .eco: return "Éco"
        }
    }
}

struct RoutePreferences: Codable, Equatable, Sendable {
    var avoidHighways: Bool
    var avoidTolls: Bool
    var preferHighways: Bool
    var preferScenic: Bool
    var mode: TravelMode

    enum CodingKeys: String, CodingKey {
        case avoidHighways, avoidTolls, preferHighways, preferScenic, mode
    }

    init(
        avoidHighways: Bool = false,
        avoidTolls: Bool = false,
        preferHighways: Bool = false,
        preferScenic: Bool = false,
        mode: TravelMode = .normal
    ) {
        self.avoidHighways = avoidHighways
        self.avoidTolls = avoidTolls
        self.preferHighways = preferHighways
        self.preferScenic = preferScenic
        self.mode = mode
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        avoidHighways = try container.decodeIfPresent(Bool.self, forKey: .avoidHighways) ?? false
        avoidTolls = try container.decodeIfPresent(Bool.self, forKey: .avoidTolls) ?? false
        preferHighways = try container.decodeIfPresent(Bool.self, forKey: .preferHighways) ?? false
        preferScenic = try container.decodeIfPresent(Bool.self, forKey: .preferScenic) ?? false
        mode = try container.decodeIfPresent(TravelMode.self, forKey: .mode) ?? .normal
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(avoidHighways, forKey: .avoidHighways)
        try container.encode(avoidTolls, forKey: .avoidTolls)
        try container.encode(preferHighways, forKey: .preferHighways)
        try container.encode(preferScenic, forKey: .preferScenic)
        try container.encode(mode, forKey: .mode)
    }

    var summaryText: String {
        var items: [String] = []
        if mode == .eco { items.append("mode éco") }
        if avoidHighways { items.append("évite autoroutes") }
        if avoidTolls { items.append("évite péages") }
        if preferHighways { items.append("préfère autoroutes") }
        if preferScenic { items.append("préfère pittoresque") }
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
