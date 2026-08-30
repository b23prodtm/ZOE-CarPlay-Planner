import Foundation
import CoreLocation

// MARK: - RealRenaultVehicleService

/// Implémentation réelle du service véhicule via l'API Renault.
///
/// TODO: Implémenter les endpoints réels en se basant sur :
///       https://github.com/hacf-fr/renault-api
///
/// Pour la ZOE II : modèle X102VE
/// L'application ne doit JAMAIS bloquer si l'API est indisponible.
actor RealRenaultVehicleService: RenaultVehicleService {
    private let apiClient: RenaultAPIClient
    private let vin: String  // Numéro de châssis du véhicule

    init(apiClient: RenaultAPIClient, vin: String) {
        self.apiClient = apiClient
        self.vin = vin
    }

    func getVehicleStatus() async throws -> VehicleStatus {
        let battery = try await getBatteryState()
        let charging = try await getChargingStatus()
        return VehicleStatus(
            battery: battery,
            charging: charging,
            odometer: nil,   // TODO: endpoint kilométrage
            isReachable: true,
            lastSeen: Date()
        )
    }

    func getBatteryState() async throws -> BatteryState {
        // TODO: GET /accounts/{accountId}/vehicles/{vin}/battery-status
        // Exemple de path Kamereon pour ZOE II :
        // /accounts/{accountId}/vehicles/{vin}/charges/settings
        throw RenaultServiceError.apiUnavailable  // Placeholder
    }

    func getVehicleLocation() async throws -> CLLocationCoordinate2D? {
        // TODO: GET /accounts/{accountId}/vehicles/{vin}/location
        throw RenaultServiceError.apiUnavailable  // Placeholder
    }

    func getChargingStatus() async throws -> ChargingStatus {
        // TODO: GET /accounts/{accountId}/vehicles/{vin}/charging-settings
        throw RenaultServiceError.apiUnavailable  // Placeholder
    }
}

// MARK: - RenaultMapper

/// Convertit les réponses JSON Renault en modèles locaux.
enum RenaultMapper {
    static func batteryState(from json: [String: Any]) throws -> BatteryState {
        // TODO: Parser la réponse JSON de l'endpoint battery-status
        // Structure attendue basée sur renault-api (hacf-fr) :
        // {
        //   "data": {
        //     "type": "Car",
        //     "attributes": {
        //       "timestamp": "...",
        //       "batteryLevel": 82,
        //       "batteryAutonomy": 245,
        //       "batteryCapacity": 0,
        //       "batteryAvailableEnergy": 41,
        //       "plugStatus": 1,
        //       "chargingStatus": 1.0
        //     }
        //   }
        // }
        throw RenaultServiceError.dataUnavailable
    }
}
