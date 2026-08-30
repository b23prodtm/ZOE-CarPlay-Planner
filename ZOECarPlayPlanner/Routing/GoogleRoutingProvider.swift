import Foundation
import CoreLocation

// MARK: - GoogleRoutingProvider

/// Fournisseur de routage optionnel via Google Routes API.
/// PRIORITÉ 3 — nécessite une clé API Google (non obligatoire).
/// L'application fonctionne sans ce fournisseur.
///
/// Pour activer : définir la clé dans Config.swift (jamais dans le dépôt Git).
struct GoogleRoutingProvider: RoutingProvider {
    private let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func calculateRoute(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) async throws -> Route {
        // TODO: Implémenter l'appel Google Routes API v2
        // POST https://routes.googleapis.com/directions/v2:computeRoutes
        // Header: X-Goog-Api-Key: {apiKey}
        //
        // Pour l'instant, déléguer au MockRoutingProvider en fallback.
        let mock = MockRoutingProvider()
        return try await mock.calculateRoute(from: origin, to: destination)
    }
}
