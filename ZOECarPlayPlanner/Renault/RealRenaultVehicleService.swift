import Foundation
import CoreLocation

// MARK: - RealRenaultVehicleService
//
// Implémentation réelle du service véhicule via l'API Kamereon/Renault.
// Référence : https://github.com/hacf-fr/renault-api
//
// ZOE II : modèle X102VE
// L'application ne bloque JAMAIS si l'API est indisponible.

actor RealRenaultVehicleService: RenaultVehicleService {
    private let apiClient: RenaultAPIClient
    /// VIN du véhicule (numéro de châssis)
    private let vin: String

    init(apiClient: RenaultAPIClient, vin: String) {
        self.apiClient = apiClient
        self.vin = vin
    }

    // MARK: - RenaultVehicleService

    func getVehicleStatus() async throws -> VehicleStatus {
        async let battery  = getBatteryState()
        async let charging = getChargingStatus()
        // Kilométrage en parallèle — on accepte nil si indisponible
        async let cockpit  = fetchCockpit()

        let b = try await battery
        let c = try await charging
        let odometer = try? await cockpit

        return VehicleStatus(
            battery: b,
            charging: c,
            odometer: odometer,
            isReachable: true,
            lastSeen: Date()
        )
    }

    func getBatteryState() async throws -> BatteryState {
        let accountId = try await apiClient.accountId()
        let path = "/accounts/\(accountId)/vehicles/\(vin)/battery-status?type=json"
        let data  = try await apiClient.get(path: path)
        return try RenaultMapper.batteryState(from: data)
    }

    func getVehicleLocation() async throws -> CLLocationCoordinate2D? {
        let accountId = try await apiClient.accountId()
        let path = "/accounts/\(accountId)/vehicles/\(vin)/location"
        let data  = try await apiClient.get(path: path)
        return try RenaultMapper.location(from: data)
    }

    func getChargingStatus() async throws -> ChargingStatus {
        let accountId = try await apiClient.accountId()
        let path = "/accounts/\(accountId)/vehicles/\(vin)/charging-settings"
        let data  = try await apiClient.get(path: path)
        return try RenaultMapper.chargingStatus(from: data)
    }

    // MARK: - Private endpoints

    private func fetchCockpit() async throws -> Double? {
        let accountId = try await apiClient.accountId()
        let path = "/accounts/\(accountId)/vehicles/\(vin)/cockpit?type=json"
        let data  = try await apiClient.get(path: path)
        return try RenaultMapper.odometer(from: data)
    }
}

// MARK: - RenaultMapper
//
// Convertit les réponses JSON Kamereon en modèles locaux.
// Structure basée sur hacf-fr/renault-api (Kamereon v1).
//
// Réponse typique battery-status :
// {
//   "data": {
//     "type": "Car",
//     "attributes": {
//       "timestamp": "2024-01-15T10:30:00+01:00",
//       "batteryLevel": 82,
//       "batteryAutonomy": 245,
//       "batteryCapacity": 0,
//       "batteryAvailableEnergy": 41,
//       "plugStatus": 1,          // 0=unplugged, 1=plugged
//       "chargingStatus": 1.0,    // -1=not_in_charge, 0.1=waiting, 1.0=in_charge
//       "chargingRemainingTime": 35,
//       "chargingInstantaneousPower": 7400  // Watts
//     }
//   }
// }

enum RenaultMapper {

    // MARK: - Battery State

    static func batteryState(from data: Data) throws -> BatteryState {
        let attrs = try attributes(from: data)

        guard let level = attrs["batteryLevel"] as? Int else {
            throw RenaultServiceError.dataUnavailable
        }
        let autonomy      = (attrs["batteryAutonomy"]  as? Int).map(Double.init) ?? estimatedRange(soc: Double(level))
        let plugStatus    = (attrs["plugStatus"]        as? Int) ?? 0
        let chargingValue = (attrs["chargingStatus"]    as? Double) ?? -1.0
        let powerW        = (attrs["chargingInstantaneousPower"] as? Double) ?? 0
        let powerKW       = powerW > 0 ? powerW / 1000.0 : nil
        let isCharging    = chargingValue == 1.0
        let timestamp     = (attrs["timestamp"] as? String).flatMap(parseDate) ?? Date()

        return BatteryState(
            stateOfChargePercent: Double(level),
            estimatedRangeKm: autonomy,
            isCharging: isCharging,
            chargingPowerKW: isCharging ? powerKW : nil,
            targetChargePercent: nil,
            lastUpdated: timestamp
        )
    }

    // MARK: - Location

    static func location(from data: Data) throws -> CLLocationCoordinate2D? {
        let attrs = try attributes(from: data)
        guard let lat = attrs["gpsLatitude"]  as? Double,
              let lon = attrs["gpsLongitude"] as? Double
        else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    // MARK: - Charging Status

    static func chargingStatus(from data: Data) throws -> ChargingStatus {
        let attrs = try attributes(from: data)
        // mode : "schedule_mode", "always_charging", etc.
        // chargingStatus peut venir de battery-status aussi
        if let cs = attrs["chargingStatus"] as? Double {
            switch cs {
            case 1.0:  return .charging
            case 0.1:  return .connected
            case -1.0: return .notConnected
            default:   return .connected
            }
        }
        return .notConnected
    }

    // MARK: - Cockpit (odometer)

    static func odometer(from data: Data) throws -> Double? {
        let attrs = try attributes(from: data)
        return attrs["totalMileage"] as? Double
    }

    // MARK: - Helpers

    private static func attributes(from data: Data) throws -> [String: Any] {
        guard let json    = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"]       as? [String: Any],
              let attrs   = dataObj["attributes"] as? [String: Any]
        else { throw RenaultServiceError.dataUnavailable }
        return attrs
    }

    private static func estimatedRange(soc: Double) -> Double {
        // Estimation ZOE ZE50 : ~298 km à 100 %
        soc / 100.0 * 298.0
    }

    private static func parseDate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = formatter.date(from: string) { return d }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}
