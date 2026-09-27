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

    func test_route_originCoordinatePreserved() async throws {
        let route = try await provider.calculateRoute(from: lyon, to: geneve)
        XCTAssertEqual(route.origin.coordinate.latitude, lyon.latitude, accuracy: 0.001)
    }
}
