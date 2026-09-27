import Foundation
import CoreLocation

// MARK: - RenaultVehicleService Protocol

/// Abstraction de l'accès aux données du véhicule Renault.
/// Implémentée par MockRenaultVehicleService et RealRenaultVehicleService.
protocol RenaultVehicleService: Sendable {
    func getVehicleStatus() async throws -> VehicleStatus
    func getBatteryState() async throws -> BatteryState
    func getVehicleLocation() async throws -> CLLocationCoordinate2D?
    func getChargingStatus() async throws -> ChargingStatus
}

// MARK: - RenaultServiceError

enum RenaultServiceError: LocalizedError {
    case notAuthenticated
    case networkError(underlying: Error)
    case apiUnavailable
    case vehicleOffline
    case dataUnavailable
    case timeout
    case tokenExpired
    case unauthorized
    case unknownError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:         return "Non authentifié"
        case .networkError(let e):      return "Erreur réseau : \(e.localizedDescription)"
        case .apiUnavailable:           return "API Renault indisponible"
        case .vehicleOffline:           return "Véhicule hors ligne"
        case .dataUnavailable:          return "Données non disponibles"
        case .timeout:                  return "Délai dépassé"
        case .tokenExpired:             return "Session expirée"
        case .unauthorized:             return "Accès refusé (clé API expirée ou 2FA requis)"
        case .unknownError(let msg):    return msg
        }
    }
}
