import XCTest
import CoreLocation
@testable import ZOECarPlayPlanner

// MARK: - MockRoutingTests

final class MockRoutingTests: XCTestCase {

    private let provider = MockRoutingProvider()

    // Lyon
    private let lyon = CLLocationCoordinate2D(latitude: 45.7640, longitude: 4.8357)
    // Genève
    private let geneve = CLLocationCoordinate2D(latitude: 46.2044, longitude: 6.1432)
    // Paris
    private let paris = CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522)

    func test_routeLyonGeneve_distanceReasonable() async throws {
        let route = try await provider.calculateRoute(from: lyon, to: geneve)
        // Lyon → Genève ≈ 130–180 km par route
        XCTAssertGreaterThan(route.totalDistanceKm, 100)
        XCTAssertLessThan(route.totalDistanceKm, 250)
    }

    func test_routeLyonParis_distanceReasonable() async throws {
        let route = try await provider.calculateRoute(from: lyon, to: paris)
        // Lyon → Paris ≈ 400–550 km
        XCTAssertGreaterThan(route.totalDistanceKm, 350)
        XCTAssertLessThan(route.totalDistanceKm, 600)
    }

    func test_sameOriginDestination_distanceNearZero() async throws {
        let route = try await provider.calculateRoute(from: lyon, to: lyon)
        XCTAssertLessThan(route.totalDistanceKm, 1.0)
    }

    func test_route_durationIsPositive() async throws {
        let route = try await provider.calculateRoute(from: lyon, to: paris)
        XCTAssertGreaterThan(route.estimatedDurationMinutes, 0)
    }


    func test_preferences_avoidHighwaysLongerThanPreferHighways() async throws {
        let avoid = try await provider.calculateRoute(
            from: lyon,
            to: paris,
            preferences: RoutePreferences(avoidHighways: true)
        )
        let prefer = try await provider.calculateRoute(
            from: lyon,
            to: paris,
            preferences: RoutePreferences(preferHighways: true)
        )

        XCTAssertGreaterThan(avoid.totalDistanceKm, prefer.totalDistanceKm)
    }

    func test_ecoMode_hasLongerDurationThanNormal() async throws {
        let normal = try await provider.calculateRoute(
            from: lyon,
            to: geneve,
            preferences: RoutePreferences(mode: .normal)
        )
        let eco = try await provider.calculateRoute(
            from: lyon,
            to: geneve,
            preferences: RoutePreferences(mode: .eco)
        )

        XCTAssertGreaterThan(eco.estimatedDurationMinutes, normal.estimatedDurationMinutes)
    }

    func test_preferScenic_increasesDistance() async throws {
        let standard = try await provider.calculateRoute(
            from: lyon,
            to: geneve,
            preferences: RoutePreferences()
        )
        let scenic = try await provider.calculateRoute(
            from: lyon,
            to: geneve,
            preferences: RoutePreferences(preferScenic: true)
        )

        XCTAssertGreaterThan(scenic.totalDistanceKm, standard.totalDistanceKm)
    }



    func test_cumulativeDistances_withMultipleWaypoints_areIncreasing() {
        let waypointDistances = AppState.cumulativeDistances(for: [95.0, 80.0])

        XCTAssertEqual(waypointDistances.count, 2)
        XCTAssertEqual(waypointDistances[0], 95.0, accuracy: 0.001)
        XCTAssertEqual(waypointDistances[1], 175.0, accuracy: 0.001)
        XCTAssertGreaterThan(waypointDistances[1], waypointDistances[0])
    }

    func test_routePreferencesDecode_withoutMode_defaultsToNormal() throws {
        let legacyJSON = #"{"avoidHighways":true,"avoidTolls":false,"preferHighways":false,"preferScenic":true}"#
        let data = try XCTUnwrap(legacyJSON.data(using: .utf8))

        let prefs = try JSONDecoder().decode(RoutePreferences.self, from: data)

        XCTAssertEqual(prefs.mode, .normal)
        XCTAssertTrue(prefs.avoidHighways)
        XCTAssertTrue(prefs.preferScenic)
    }


    func test_legacyPlannedTripHistoryDecode_withoutMode() throws {
        let legacyJSON = #"""
        [
          {
            "id": "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE",
            "origin": {
              "id": "11111111-1111-1111-1111-111111111111",
              "name": "Lyon",
              "latitude": 45.7640,
              "longitude": 4.8357
            },
            "destination": {
              "id": "22222222-2222-2222-2222-222222222222",
              "name": "Paris",
              "latitude": 48.8566,
              "longitude": 2.3522
            },
            "waypoints": [],
            "preferences": {
              "avoidHighways": true,
              "avoidTolls": false,
              "preferHighways": false,
              "preferScenic": false
            },
            "searchedAt": 0
          }
        ]
        """#

        let data = try XCTUnwrap(legacyJSON.data(using: .utf8))
        let decoded = try JSONDecoder().decode([PlannedTrip].self, from: data)

        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].preferences.mode, .normal)
        XCTAssertTrue(decoded[0].preferences.avoidHighways)
    }

    func test_plannedTripRoundTrip_preservesPreferences() throws {
        let trip = PlannedTrip(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            origin: TripPlace(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                name: "Lyon",
                coordinate: lyon
            ),
            destination: TripPlace(
                id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                name: "Paris",
                coordinate: paris
            ),
            waypoints: [
                TripPlace(
                    id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
                    name: "Auxerre",
                    coordinate: CLLocationCoordinate2D(latitude: 47.7982, longitude: 3.5738)
                )
            ],
            preferences: RoutePreferences(avoidTolls: true, preferScenic: true, mode: .eco),
            searchedAt: Date(timeIntervalSince1970: 1_725_000_000)
        )

        let data = try JSONEncoder().encode(trip)
        let decoded = try JSONDecoder().decode(PlannedTrip.self, from: data)

        XCTAssertEqual(decoded, trip)
    }



    func test_stationMapSymbol_matchesHighwayType() {
        let highway = ChargingStation(
            id: UUID(),
            name: "Aire",
            coordinate: lyon,
            network: .ionity,
            connectors: [],
            isAvailable: true,
            distanceFromRouteKm: 100,
            isHighway: true
        )
        let local = ChargingStation(
            id: UUID(),
            name: "Ville",
            coordinate: paris,
            network: .local,
            connectors: [],
            isAvailable: true,
            distanceFromRouteKm: 120,
            isHighway: false
        )

        XCTAssertEqual(highway.mapSymbolName, "road.lanes")
        XCTAssertEqual(local.mapSymbolName, "bolt.fill")
    }

    func test_stationProvider_prefersHighwayStationsWhenHighwaysAllowed() async throws {
        let provider = MockChargingStationProvider()
        let route = Route(
            origin: RoutePoint(name: "Lyon", coordinate: lyon),
            destination: RoutePoint(name: "Paris", coordinate: paris, distanceFromOriginKm: 400),
            totalDistanceKm: 400,
            estimatedDurationMinutes: 260,
            routePreferences: RoutePreferences(avoidHighways: false)
        )

        let stations = try await provider.findStations(
            along: route,
            connectorTypes: Vehicle.defaultZOE.connectorTypes,
            networks: ChargingNetwork.allCases
        )

        XCTAssertFalse(stations.isEmpty)
        XCTAssertTrue(stations.allSatisfy { $0.isHighway == true })
        XCTAssertTrue(stations.allSatisfy { $0.name.contains("Aire de") })
        XCTAssertTrue(stations.allSatisfy { [.ionity, .electra, .totalEnergies, .fastned].contains($0.network) })
    }


    func test_stationProvider_shortRoute_returnsNoStations() async throws {
        let provider = MockChargingStationProvider()
        let route = Route(
            origin: RoutePoint(name: "Lyon", coordinate: lyon),
            destination: RoutePoint(name: "Proche", coordinate: CLLocationCoordinate2D(latitude: 45.90, longitude: 4.90), distanceFromOriginKm: 60),
            totalDistanceKm: 60,
            estimatedDurationMinutes: 50,
            routePreferences: RoutePreferences(avoidHighways: false)
        )

        let stations = try await provider.findStations(
            along: route,
            connectorTypes: Vehicle.defaultZOE.connectorTypes,
            networks: ChargingNetwork.allCases
        )

        XCTAssertTrue(stations.isEmpty)
    }

    func test_stationProvider_usesNonHighwayStationsWhenAvoidHighways() async throws {
        let provider = MockChargingStationProvider()
        let route = Route(
            origin: RoutePoint(name: "Lyon", coordinate: lyon),
            destination: RoutePoint(name: "Paris", coordinate: paris, distanceFromOriginKm: 400),
            totalDistanceKm: 400,
            estimatedDurationMinutes: 260,
            routePreferences: RoutePreferences(avoidHighways: true)
        )

        let stations = try await provider.findStations(
            along: route,
            connectorTypes: Vehicle.defaultZOE.connectorTypes,
            networks: ChargingNetwork.allCases
        )

        XCTAssertFalse(stations.isEmpty)
        XCTAssertTrue(stations.allSatisfy { $0.isHighway == false })
        XCTAssertTrue(stations.allSatisfy { $0.name.contains("Borne") })
        XCTAssertTrue(stations.allSatisfy { [.electra, .totalEnergies, .allego, .local].contains($0.network) })
    }

    func test_stationProvider_placesStationsAlongRoutePath() async throws {
        let provider = MockChargingStationProvider()
        let route = Route(
            origin: RoutePoint(name: "A", coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0)),
            destination: RoutePoint(name: "C", coordinate: CLLocationCoordinate2D(latitude: 1, longitude: 1), distanceFromOriginKm: 240),
            totalDistanceKm: 240,
            estimatedDurationMinutes: 180,
            routePreferences: RoutePreferences(avoidHighways: false),
            path: [
                RouteCoordinate(latitude: 0, longitude: 0),
                RouteCoordinate(latitude: 1, longitude: 0),
                RouteCoordinate(latitude: 1, longitude: 1)
            ]
        )

        let stations = try await provider.findStations(
            along: route,
            connectorTypes: Vehicle.defaultZOE.connectorTypes,
            networks: ChargingNetwork.allCases
        )

        XCTAssertGreaterThanOrEqual(stations.count, 4)
        XCTAssertTrue(stations.contains { abs($0.coordinate.longitude) < 0.05 }, "Au moins une borne doit rester sur le premier segment du trajet.")
        XCTAssertTrue(stations.contains { $0.coordinate.latitude > 0.95 }, "Au moins une borne doit suivre la fin du parcours, pas la diagonale origine-destination.")
    }

    func test_stationProvider_generatesAlternativeChoicesNearSameStop() async throws {
        let provider = MockChargingStationProvider()
        let route = Route(
            origin: RoutePoint(name: "Lyon", coordinate: lyon),
            destination: RoutePoint(name: "Paris", coordinate: paris, distanceFromOriginKm: 400),
            totalDistanceKm: 400,
            estimatedDurationMinutes: 260,
            routePreferences: RoutePreferences(avoidHighways: false)
        )

        let stations = try await provider.findStations(
            along: route,
            connectorTypes: Vehicle.defaultZOE.connectorTypes,
            networks: ChargingNetwork.allCases
        )

        let nearbyAlternatives = stations.filter { abs($0.distanceFromRouteKm - 80) <= 10 }
        XCTAssertGreaterThanOrEqual(nearbyAlternatives.count, 2)
    }

    func test_route_originCoordinatePreserved() async throws {
        let route = try await provider.calculateRoute(from: lyon, to: geneve)
        XCTAssertEqual(route.origin.coordinate.latitude, lyon.latitude, accuracy: 0.001)
    }

    func test_stationProvider_filtersByNetworkAndConnector() async throws {
        let provider = MockChargingStationProvider()
        let route = Route(
            origin: RoutePoint(name: "Lyon", coordinate: lyon),
            destination: RoutePoint(name: "Paris", coordinate: paris, distanceFromOriginKm: 400),
            totalDistanceKm: 400,
            estimatedDurationMinutes: 260,
            routePreferences: RoutePreferences(avoidHighways: false)
        )

        let stations = try await provider.findStations(
            along: route,
            connectorTypes: [.ccs],
            networks: [.ionity]
        )

        XCTAssertFalse(stations.isEmpty)
        XCTAssertTrue(stations.allSatisfy { $0.network == .ionity })
        XCTAssertTrue(stations.allSatisfy { $0.connectors.contains(where: { $0.type == .ccs }) })
    }

    func test_plannerSettingsDecode_withoutNewFields_keepsDefaults() throws {
        let legacyJSON = #"""
        {
          "consumptionWhPerKm": 170,
          "minBatteryAtArrivalPercent": 15,
          "maxBatteryAfterChargePercent": 80,
          "safetyMarginPercent": 10,
          "preferredChargingPowerKW": 22,
          "useSimulationMode": true,
          "simulatedSOCPercent": 82,
          "vehicle": {
            "id": "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE",
            "name": "Renault ZOE",
            "model": "ZE50 R110",
            "batteryCapacityKWh": 52,
            "usableBatteryKWh": 50,
            "defaultConsumptionWhPerKm": 170,
            "maxChargingPowerAC": 22,
            "maxChargingPowerDC": 0,
            "connectorTypes": ["Type 2 AC"]
          },
          "routePreferences": {
            "avoidHighways": false,
            "avoidTolls": false,
            "preferHighways": false,
            "preferScenic": false,
            "mode": "normal"
          }
        }
        """#

        let data = try XCTUnwrap(legacyJSON.data(using: .utf8))
        let settings = try JSONDecoder().decode(PlannerSettings.self, from: data)

        XCTAssertEqual(settings.selectedChargingNetworks, ChargingNetwork.allCases)
        XCTAssertEqual(settings.selectedConnectorTypes, [.type2AC, .ccs])
        XCTAssertTrue(settings.preferHighwayStations)
        XCTAssertEqual(settings.preferredNavigationApp, .appleMaps)
        XCTAssertNil(settings.dashboardWallpaperFilename)
    }

    func test_routePlannerValidation_requiresDistinctOriginAndDestination() {
        let lyonPlace = TripPlace(name: "Lyon", coordinate: lyon)
        let genevePlace = TripPlace(name: "Genève", coordinate: geneve)

        XCTAssertFalse(RoutePlannerValidation.canPlanTrip(origin: nil, destination: genevePlace))
        XCTAssertFalse(RoutePlannerValidation.canPlanTrip(origin: lyonPlace, destination: nil))
        XCTAssertFalse(RoutePlannerValidation.canPlanTrip(origin: lyonPlace, destination: lyonPlace))
        XCTAssertTrue(RoutePlannerValidation.canPlanTrip(origin: lyonPlace, destination: genevePlace))
    }
}
