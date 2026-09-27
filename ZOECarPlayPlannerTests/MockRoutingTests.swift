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

    func test_route_originCoordinatePreserved() async throws {
        let route = try await provider.calculateRoute(from: lyon, to: geneve)
        XCTAssertEqual(route.origin.coordinate.latitude, lyon.latitude, accuracy: 0.001)
    }
}
