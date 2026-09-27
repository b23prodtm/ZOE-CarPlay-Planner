import XCTest
@testable import ZOECarPlayPlanner

// MARK: - MockVehicleServiceTests

final class MockVehicleServiceTests: XCTestCase {

    func test_defaultScenario_returnsBatteryState() async throws {
        let service = MockRenaultVehicleService(scenario: .high)
        let battery = try await service.getBatteryState()
        XCTAssertEqual(battery.stateOfChargePercent, 80, accuracy: 0.01)
        XCTAssertGreaterThan(battery.estimatedRangeKm, 0)
    }

    func test_fullScenario_returns100Percent() async throws {
        let service = MockRenaultVehicleService(scenario: .full)
        let battery = try await service.getBatteryState()
        XCTAssertEqual(battery.stateOfChargePercent, 100, accuracy: 0.01)
    }

    func test_chargingScenario_isCharging() async throws {
        let service = MockRenaultVehicleService(scenario: .charging)
        let battery = try await service.getBatteryState()
        XCTAssertTrue(battery.isCharging)
        XCTAssertNotNil(battery.chargingPowerKW)
    }

    func test_disconnectedScenario_noLocation() async throws {
        let service = MockRenaultVehicleService(scenario: .disconnected)
        let location = try await service.getVehicleLocation()
        XCTAssertNil(location, "Le véhicule non connecté ne doit pas retourner de localisation")
    }

    func test_customSOC_isRespected() async throws {
        let service = MockRenaultVehicleService(scenario: .high)
        await service.setCustomSOC(55)
        let battery = try await service.getBatteryState()
        XCTAssertEqual(battery.stateOfChargePercent, 55, accuracy: 0.01)
    }

    func test_vehicleStatus_hasValidOdometer() async throws {
        let service = MockRenaultVehicleService(scenario: .half)
        let status = try await service.getVehicleStatus()
        XCTAssertNotNil(status.odometer)
    }

    func test_allScenarios_doNotThrow() async {
        for scenario in SimulationScenario.allCases {
            let service = MockRenaultVehicleService(scenario: scenario)
            do {
                _ = try await service.getBatteryState()
            } catch {
                XCTFail("Scénario \(scenario.rawValue) a levé une erreur : \(error)")
            }
        }
    }
}
