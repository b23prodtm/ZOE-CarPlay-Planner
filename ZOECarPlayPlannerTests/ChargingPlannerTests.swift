import XCTest
@testable import ZOECarPlayPlanner

// MARK: - ChargingPlannerTests

final class ChargingPlannerTests: XCTestCase {

    private let planner = ChargingPlanner()
    private let usableBattery = 50.0    // kWh
    private let consumption = 170.0     // Wh/km
    private let chargingPower = 22.0    // kW
    private let defaultStrategy = ChargingStrategy.default

    // MARK: - Helpers

    private func makeInput(
        socPercent: Double,
        distanceKm: Double,
        strategy: ChargingStrategy? = nil,
        stations: [ChargingStation] = []
    ) -> ChargingPlannerInput {
        ChargingPlannerInput(
            currentSOCPercent: socPercent,
            usableBatteryKWh: usableBattery,
            consumptionWhPerKm: consumption,
            distanceKm: distanceKm,
            strategy: strategy ?? defaultStrategy,
            chargingPowerKW: chargingPower,
            availableStations: stations,
            roadTypes: .typical
        )
    }

    // MARK: - Tests trajet inférieur à l'autonomie

    func test_shortTrip_noChargingRequired() {
        // Lyon → Genève ≈ 150 km, batterie 82 % → bien dans l'autonomie
        let plan = planner.plan(input: makeInput(socPercent: 82, distanceKm: 150))
        XCTAssertFalse(plan.requiresCharging, "Aucune recharge ne devrait être nécessaire")
        XCTAssertEqual(plan.numberOfStops, 0)
        XCTAssertGreaterThan(plan.estimatedArrivalSOCPercent, 15, "SOC à l'arrivée doit être > seuil min")
    }

    // MARK: - Tests 100 % batterie

    func test_fullBattery_longTrip() {
        let plan = planner.plan(input: makeInput(socPercent: 100, distanceKm: 500))
        // Lyon → Paris ≈ 465 km, une recharge attendue à 100 %
        XCTAssertGreaterThanOrEqual(plan.numberOfStops, 1)
    }

    // MARK: - Tests 80 % batterie

    func test_80Percent_mediumTrip() {
        let plan = planner.plan(input: makeInput(socPercent: 80, distanceKm: 350))
        XCTAssertGreaterThanOrEqual(plan.numberOfStops, 1)
        XCTAssertGreaterThanOrEqual(plan.estimatedArrivalSOCPercent, 0)
    }

    // MARK: - Tests 50 % batterie

    func test_50Percent_directTrip() {
        let plan = planner.plan(input: makeInput(socPercent: 50, distanceKm: 100))
        XCTAssertEqual(plan.numberOfStops, 0)
    }

    // MARK: - Tests 20 % batterie

    func test_20Percent_shortTrip() {
        // Très peu d'autonomie restante
        let plan = planner.plan(input: makeInput(socPercent: 20, distanceKm: 40))
        XCTAssertEqual(plan.numberOfStops, 0)
        XCTAssertGreaterThanOrEqual(plan.estimatedArrivalSOCPercent, 0)
    }

    func test_20Percent_longTrip_multipleCharges() {
        let plan = planner.plan(input: makeInput(socPercent: 20, distanceKm: 600))
        XCTAssertGreaterThanOrEqual(plan.numberOfStops, 2)
    }

    // MARK: - Trajet nécessitant 1 recharge

    func test_oneChargeRequired() {
        let plan = planner.plan(input: makeInput(socPercent: 80, distanceKm: 280))
        XCTAssertEqual(plan.numberOfStops, 1, "Un seul arrêt attendu")
        XCTAssertGreaterThan(plan.stops[0].estimatedChargeDurationMinutes, 0)
    }

    // MARK: - Trajet nécessitant 2 recharges

    func test_twoChargesRequired() {
        let plan = planner.plan(input: makeInput(socPercent: 82, distanceKm: 550))
        XCTAssertGreaterThanOrEqual(plan.numberOfStops, 2)
    }

    // MARK: - Marge de sécurité

    func test_safetyMarginIncreasesStops() {
        let aggressive = ChargingStrategy(minimumSOCPercent: 5, targetSOCPercent: 80, safetyMarginPercent: 0)
        let conservative = ChargingStrategy(minimumSOCPercent: 15, targetSOCPercent: 80, safetyMarginPercent: 15)

        let planA = planner.plan(input: makeInput(socPercent: 80, distanceKm: 350, strategy: aggressive))
        let planC = planner.plan(input: makeInput(socPercent: 80, distanceKm: 350, strategy: conservative))

        XCTAssertLessThanOrEqual(planA.numberOfStops, planC.numberOfStops,
            "La stratégie conservatrice doit déclencher au moins autant d'arrêts")
    }

    // MARK: - Consommation différente

    func test_higherConsumption_moreStops() {
        let lowInput = ChargingPlannerInput(
            currentSOCPercent: 80,
            usableBatteryKWh: usableBattery,
            consumptionWhPerKm: 150,
            distanceKm: 400,
            strategy: defaultStrategy,
            chargingPowerKW: chargingPower,
            availableStations: [],
            roadTypes: .allHighway
        )
        let highInput = ChargingPlannerInput(
            currentSOCPercent: 80,
            usableBatteryKWh: usableBattery,
            consumptionWhPerKm: 250,
            distanceKm: 400,
            strategy: defaultStrategy,
            chargingPowerKW: chargingPower,
            availableStations: [],
            roadTypes: .allHighway
        )
        let planLow = planner.plan(input: lowInput)
        let planHigh = planner.plan(input: highInput)

        XCTAssertLessThanOrEqual(planLow.numberOfStops, planHigh.numberOfStops,
            "Consommation plus élevée → plus d'arrêts")
    }

    // MARK: - Arrivée sous le seuil minimum

    func test_arrivalSOCNeverNegative() {
        let plan = planner.plan(input: makeInput(socPercent: 5, distanceKm: 300))
        XCTAssertGreaterThanOrEqual(plan.estimatedArrivalSOCPercent, 0)
    }

    // MARK: - Trajet très long

    func test_veryLongTrip_stopsLimitedTo20() {
        let plan = planner.plan(input: makeInput(socPercent: 80, distanceKm: 5000))
        XCTAssertLessThanOrEqual(plan.numberOfStops, 20, "Protection contre les boucles infinies")
    }

    // MARK: - Durée de recharge

    func test_chargeDuration_isPositive() {
        let plan = planner.plan(input: makeInput(socPercent: 50, distanceKm: 350))
        for stop in plan.stops {
            XCTAssertGreaterThan(stop.estimatedChargeDurationMinutes, 0)
            XCTAssertGreaterThan(stop.energyToAddKWh, 0)
        }
    }
}
