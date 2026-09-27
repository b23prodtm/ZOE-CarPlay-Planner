import SwiftUI
import CoreLocation
@preconcurrency import MapKit

private let dashboardDefaultRegion = MKCoordinateRegion(
    center: CLLocationCoordinate2D(latitude: 46.4, longitude: 4.7),
    span: MKCoordinateSpan(latitudeDelta: 5.0, longitudeDelta: 5.0)
)

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @State private var dashboardMapPosition: MapCameraPosition = .region(dashboardDefaultRegion)

    private var dashboardRoutePolyline: MKPolyline? {
        let coordinates = appState.currentRoute?.path.map(\.coordinate) ?? []
        guard coordinates.count >= 2 else { return nil }
        return MKPolyline(coordinates: coordinates, count: coordinates.count)
    }

    private var dashboardMapPoints: [DashboardMapPoint] {
        if let route = appState.currentRoute {
            var points = [
                DashboardMapPoint(
                    id: "origin",
                    title: route.origin.name,
                    coordinate: route.origin.coordinate,
                    tint: .blue,
                    symbol: "play.circle.fill"
                ),
                DashboardMapPoint(
                    id: "destination",
                    title: route.destination.name,
                    coordinate: route.destination.coordinate,
                    tint: .red,
                    symbol: "flag.circle.fill"
                )
            ]

            points.append(contentsOf: route.waypoints.enumerated().map { index, waypoint in
                DashboardMapPoint(
                    id: "waypoint-\(waypoint.id.uuidString)",
                    title: "Étape \(index + 1)",
                    coordinate: waypoint.coordinate,
                    tint: .purple,
                    symbol: "point.topleft.down.curvedto.point.bottomright.up"
                )
            })
            return points
        }

        guard let latestTrip = appState.routeHistory.first else { return [] }
        var points = [
            DashboardMapPoint(
                id: "history-origin",
                title: latestTrip.origin.name,
                coordinate: latestTrip.origin.coordinate,
                tint: .blue,
                symbol: "play.circle.fill"
            ),
            DashboardMapPoint(
                id: "history-destination",
                title: latestTrip.destination.name,
                coordinate: latestTrip.destination.coordinate,
                tint: .red,
                symbol: "flag.circle.fill"
            )
        ]

        points.append(contentsOf: latestTrip.waypoints.enumerated().map { index, waypoint in
            DashboardMapPoint(
                id: "history-waypoint-\(waypoint.id.uuidString)",
                title: "Étape \(index + 1)",
                coordinate: waypoint.coordinate,
                tint: .purple,
                symbol: "point.topleft.down.curvedto.point.bottomright.up"
            )
        })
        return points
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Titre
                Text("ZOE CarPlay Planner")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.primary)

                plannerHeroSection

                // État batterie
                if let status = appState.vehicleStatus {
                    VehicleStatusView(status: status)
                } else if appState.isLoading {
                    ProgressView("Chargement...")
                        .padding()
                } else {
                    Text("Appuyez sur Actualiser")
                        .foregroundStyle(.secondary)
                }

                // Boutons principaux
                VStack(spacing: 16) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        DashboardButton(title: "Réglages", systemImage: "gearshape.fill", color: .gray)
                    }

                    Button {
                        Task { await appState.refreshVehicleStatus() }
                    } label: {
                        DashboardButton(title: "Actualiser", systemImage: "arrow.clockwise", color: .green)
                    }
                }
                .padding(.horizontal)

                Spacer()

                // Mode simulation
                if appState.settings.useSimulationMode {
                    Label("Mode simulation actif", systemImage: "cpu")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(.bottom, 8)
                }
            }
            .padding()
            .navigationBarHidden(true)
            .onAppear {
                fitMapToContent()
            }
            .onChange(of: appState.currentRoute?.path.map { "\($0.latitude),\($0.longitude)" } ?? []) { _, _ in
                fitMapToContent()
            }
            .onChange(of: appState.routeHistory.first?.id) { _, _ in
                fitMapToContent()
            }
            .alert("Erreur", isPresented: .constant(appState.error != nil)) {
                Button("OK") { appState.error = nil }
            } message: {
                Text(appState.error?.message ?? "")
            }
        }
    }
}

// MARK: - DashboardButton

struct DashboardButton: View {
    let title: String
    let systemImage: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: systemImage)
                .font(.title2)
            Text(title)
                .font(.title3.weight(.semibold))
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(color.opacity(0.15))
        .foregroundStyle(color)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private extension DashboardView {
    var plannerHeroSection: some View {
        ZStack(alignment: .bottomLeading) {
            Map(position: $dashboardMapPosition, interactionModes: []) {
                if let dashboardRoutePolyline {
                    MapPolyline(dashboardRoutePolyline)
                        .stroke(.blue, lineWidth: 5)
                }

                ForEach(dashboardMapPoints) { point in
                    Annotation(point.title, coordinate: point.coordinate) {
                        Image(systemName: point.symbol)
                            .font(.caption)
                            .padding(8)
                            .background(point.tint.opacity(0.15))
                            .foregroundStyle(point.tint)
                            .clipShape(Circle())
                    }
                }
            }
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Carte du trajet")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(appState.currentRoute == nil ? "Choisissez un départ et une destination." : "Reprenez la planification là où vous l'avez laissée.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.9))
                }
                .padding()
                .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
                .padding()
            }
            .overlay(alignment: .bottomLeading) {
                NavigationLink {
                    RoutePlannerView()
                } label: {
                    Label("Planifier un trajet", systemImage: "map.fill")
                        .font(.headline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(.blue, in: Capsule())
                        .foregroundStyle(.white)
                        .shadow(radius: 8)
                }
                .padding()
            }
        }
        .frame(maxWidth: .infinity, minHeight: 220, maxHeight: 260)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .accessibilityLabel("Aperçu cartographique de l’accueil")
    }

    func fitMapToContent() {
        let coordinates = dashboardMapPoints.map(\.coordinate) + (appState.currentRoute?.path.map(\.coordinate) ?? [])
        guard !coordinates.isEmpty else {
            dashboardMapPosition = .region(dashboardDefaultRegion)
            return
        }

        dashboardMapPosition = .rect(MKMapRect.boundingRect(for: coordinates))
    }
}

private struct DashboardMapPoint: Identifiable {
    let id: String
    let title: String
    let coordinate: CLLocationCoordinate2D
    let tint: Color
    let symbol: String
}

private extension MKMapRect {
    static func boundingRect(for coordinates: [CLLocationCoordinate2D]) -> MKMapRect {
        coordinates.reduce(.null) { partialResult, coordinate in
            let point = MKMapPoint(coordinate)
            let rect = MKMapRect(
                origin: point,
                size: MKMapSize(width: 1_000, height: 1_000)
            )
            return partialResult.isNull ? rect : partialResult.union(rect)
        }
    }
}
