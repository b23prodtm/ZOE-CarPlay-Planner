import XCTest
@testable import ZOECarPlayPlanner

// MARK: - RenaultMapperTests
//
// Tests du parsing JSON Kamereon → modèles locaux.
// Aucune connexion réseau n'est requise.

final class RenaultMapperTests: XCTestCase {

    // MARK: - BatteryState

    func test_batteryState_fullResponse() throws {
        let json = kamereonResponse(attributes: [
            "batteryLevel": 82,
            "batteryAutonomy": 245,
            "batteryAvailableEnergy": 41,
            "plugStatus": 1,
            "chargingStatus": 1.0,
            "chargingInstantaneousPower": 7400.0,
            "timestamp": "2024-01-15T10:30:00+01:00"
        ])
        let data = try JSONSerialization.data(withJSONObject: json)
        let state = try RenaultMapper.batteryState(from: data)

        XCTAssertEqual(state.stateOfChargePercent, 82, accuracy: 0.01)
        XCTAssertEqual(state.estimatedRangeKm, 245, accuracy: 0.01)
        XCTAssertTrue(state.isCharging)
        XCTAssertEqual(state.chargingPowerKW ?? 0, 7.4, accuracy: 0.01)
    }

    func test_batteryState_notCharging() throws {
        let json = kamereonResponse(attributes: [
            "batteryLevel": 50,
            "batteryAutonomy": 149,
            "plugStatus": 0,
            "chargingStatus": -1.0,
            "timestamp": "2024-01-15T10:30:00+01:00"
        ])
        let data = try JSONSerialization.data(withJSONObject: json)
        let state = try RenaultMapper.batteryState(from: data)

        XCTAssertEqual(state.stateOfChargePercent, 50, accuracy: 0.01)
        XCTAssertFalse(state.isCharging)
        XCTAssertNil(state.chargingPowerKW)
    }

    func test_batteryState_missingBatteryLevel_throws() throws {
        let json = kamereonResponse(attributes: ["plugStatus": 0])
        let data = try JSONSerialization.data(withJSONObject: json)
        XCTAssertThrowsError(try RenaultMapper.batteryState(from: data))
    }

    func test_batteryState_emptyJSON_throws() throws {
        let data = "{}".data(using: .utf8)!
        XCTAssertThrowsError(try RenaultMapper.batteryState(from: data))
    }

    func test_batteryState_autonomyFallback_whenMissing() throws {
        let json = kamereonResponse(attributes: [
            "batteryLevel": 100,
            "plugStatus": 1,
            "chargingStatus": -1.0,
            "timestamp": "2024-01-15T10:30:00+01:00"
        ])
        let data = try JSONSerialization.data(withJSONObject: json)
        let state = try RenaultMapper.batteryState(from: data)
        // Fallback : 100 % → ~298 km
        XCTAssertGreaterThan(state.estimatedRangeKm, 0)
    }

    // MARK: - Location

    func test_location_valid() throws {
        let json = kamereonResponse(attributes: [
            "gpsLatitude": 45.764,
            "gpsLongitude": 4.835
        ])
        let data = try JSONSerialization.data(withJSONObject: json)
        let coord = try RenaultMapper.location(from: data)
        XCTAssertNotNil(coord)
        XCTAssertEqual(coord!.latitude, 45.764, accuracy: 0.001)
        XCTAssertEqual(coord!.longitude, 4.835, accuracy: 0.001)
    }

    func test_location_missingCoords_returnsNil() throws {
        let json = kamereonResponse(attributes: ["someOtherField": "value"])
        let data = try JSONSerialization.data(withJSONObject: json)
        let coord = try RenaultMapper.location(from: data)
        XCTAssertNil(coord)
    }

    // MARK: - ChargingStatus

    func test_chargingStatus_charging() throws {
        let json = kamereonResponse(attributes: ["chargingStatus": 1.0])
        let data = try JSONSerialization.data(withJSONObject: json)
        let status = try RenaultMapper.chargingStatus(from: data)
        XCTAssertEqual(status, .charging)
    }

    func test_chargingStatus_connected_notCharging() throws {
        let json = kamereonResponse(attributes: ["chargingStatus": 0.1])
        let data = try JSONSerialization.data(withJSONObject: json)
        let status = try RenaultMapper.chargingStatus(from: data)
        XCTAssertEqual(status, .connected)
    }

    func test_chargingStatus_notConnected() throws {
        let json = kamereonResponse(attributes: ["chargingStatus": -1.0])
        let data = try JSONSerialization.data(withJSONObject: json)
        let status = try RenaultMapper.chargingStatus(from: data)
        XCTAssertEqual(status, .notConnected)
    }

    // MARK: - Odometer

    func test_odometer_valid() throws {
        let json = kamereonResponse(attributes: ["totalMileage": 24350.5])
        let data = try JSONSerialization.data(withJSONObject: json)
        let km = try RenaultMapper.odometer(from: data)
        XCTAssertEqual(km ?? 0, 24350.5, accuracy: 0.01)
    }

    func test_odometer_missing_returnsNil() throws {
        let json = kamereonResponse(attributes: [:])
        let data = try JSONSerialization.data(withJSONObject: json)
        let km = try RenaultMapper.odometer(from: data)
        XCTAssertNil(km)
    }

    // MARK: - Helpers

    private func kamereonResponse(attributes: [String: Any]) -> [String: Any] {
        [
            "data": [
                "type": "Car",
                "attributes": attributes
            ]
        ]
    }
}
