import XCTest
@testable import ZOECarPlayPlanner

// MARK: - EnergyConsumptionTests

final class EnergyConsumptionTests: XCTestCase {

    func test_defaultConsumption_typical() {
        let result = EnergyConsumptionModel.weightedConsumption(roadTypes: .typical)
        // 60% autoroute (200) + 30% route (165) + 10% ville (140) = 120+49.5+14 = 183.5
        XCTAssertEqual(result, 183.5, accuracy: 0.5)
    }

    func test_allHighway_consumptionIsHigh() {
        let result = EnergyConsumptionModel.weightedConsumption(roadTypes: .allHighway)
        XCTAssertEqual(result, 200, accuracy: 0.1)
    }

    func test_allCity_consumptionIsLow() {
        let result = EnergyConsumptionModel.weightedConsumption(roadTypes: .allCity)
        XCTAssertEqual(result, 140, accuracy: 0.1)
    }

    func test_overrideConsumption() {
        let result = EnergyConsumptionModel.weightedConsumption(
            roadTypes: .typical,
            overrideWhPerKm: 170
        )
        XCTAssertEqual(result, 170, accuracy: 0.01)
    }

    func test_energyKWh_100km_170WhPerKm() {
        let energy = EnergyConsumptionModel.energyKWh(distanceKm: 100, consumptionWhPerKm: 170)
        XCTAssertEqual(energy, 17.0, accuracy: 0.01)
    }

    func test_energyKWh_zero_distance() {
        let energy = EnergyConsumptionModel.energyKWh(distanceKm: 0, consumptionWhPerKm: 170)
        XCTAssertEqual(energy, 0.0, accuracy: 0.001)
    }
}
