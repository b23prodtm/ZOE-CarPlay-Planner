import Foundation
import CoreLocation

// MARK: - ChargingStation

/// Une borne de recharge.
struct ChargingStation: Identifiable, Sendable {
    let id: UUID
    let name: String
    let coordinate: CLLocationCoordinate2D
    let operatorName: String
    let connectors: [StationConnector]
    var isAvailable: Bool?  // nil = inconnu
    let distanceFromRouteKm: Double

    var maxPowerKW: Double {
        connectors.map { $0.powerKW }.max() ?? 0
    }

    var displayPower: String {
        "\(Int(maxPowerKW)) kW"
    }
}

// MARK: - StationConnector

struct StationConnector: Identifiable, Sendable {
    let id: UUID
    let type: ConnectorType
    let powerKW: Double
    var isAvailable: Bool?
}
