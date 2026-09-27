import Foundation
import CoreLocation

// MARK: - RoutingProvider Protocol

protocol RoutingProvider: Sendable {
    func calculateRoute(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) async throws -> Route
}

// MARK: - RoutingError

enum RoutingError: LocalizedError {
    case noRouteFound
    case networkError(underlying: Error)
    case invalidCoordinates
    case serviceUnavailable
    case rateLimitExceeded

    var errorDescription: String? {
        switch self {
        case .noRouteFound:         return "Aucun itinéraire trouvé"
        case .networkError(let e):  return "Erreur réseau : \(e.localizedDescription)"
        case .invalidCoordinates:   return "Coordonnées invalides"
        case .serviceUnavailable:   return "Service de routage indisponible"
        case .rateLimitExceeded:    return "Limite de requêtes dépassée"
        }
    }
}
