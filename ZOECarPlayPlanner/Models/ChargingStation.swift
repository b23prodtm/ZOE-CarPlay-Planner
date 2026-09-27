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
    let isHighway: Bool?

    var maxPowerKW: Double {
        connectors.map { $0.powerKW }.max() ?? 0
    }

    var displayPower: String {
        "\(Int(maxPowerKW)) kW"
    }

    var locationTypeLabel: String {
        if isHighway == true { return "Autoroute" }
        if isHighway == false { return "Hors autoroute" }
        return "Type inconnu"
    }

    var mapSymbolName: String {
        isHighway == true ? "road.lanes" : "bolt.fill"
    }
}

// MARK: - StationConnector

struct StationConnector: Identifiable, Sendable {
    let id: UUID
    let type: ConnectorType
    let powerKW: Double
    var isAvailable: Bool?
}
