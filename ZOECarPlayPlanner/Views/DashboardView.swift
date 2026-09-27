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
        var points: [DashboardMapPoint] = []

        if let route = appState.currentRoute {
            points.append(
                DashboardMapPoint(
                    id: "origin",
                    title: route.origin.name,
                    coordinate: route.origin.coordinate,
                    tint: .blue,
                    symbol: "play.circle.fill"
                )
            )
            points.append(
                DashboardMapPoint(
                    id: "destination",
                    title: route.destination.name,
                    coordinate: route.destination.coordinate,
                    tint: .red,
                    symbol: "flag.circle.fill"
                )
            )
            points.append(contentsOf: route.waypoints.enumerated().map { index, waypoint in
                DashboardMapPoint(
                    id: "waypoint-\(waypoint.id.uuidString)",
                    title: "Étape \(index + 1)",
                    coordinate: waypoint.coordinate,
                    tint: .purple,
                    symbol: "point.topleft.down.curvedto.point.bottomright.up"
                )
            })
        } else if let latestTrip = appState.routeHistory.first {
            points.append(
                DashboardMapPoint(
                    id: "history-origin",
                    title: latestTrip.origin.name,
                    coordinate: latestTrip.origin.coordinate,
                    tint: .blue,
                    symbol: "play.circle.fill"
                )
            )
            points.append(
                DashboardMapPoint(
                    id: "history-destination",
                    title: latestTrip.destination.name,
                    coordinate: latestTrip.destination.coordinate,
                    tint: .red,
                    symbol: "flag.circle.fill"
                )
            )
            points.append(contentsOf: latestTrip.waypoints.enumerated().map { index, waypoint in
                DashboardMapPoint(
                    id: "history-waypoint-\(waypoint.id.uuidString)",
                    title: "Étape \(index + 1)",
                    coordinate: waypoint.coordinate,
                    tint: .purple,
                    symbol: "point.topleft.down.curvedto.point.bottomright.up"
                )
            })
        }

        if let vehicleCoordinate = appState.currentVehicleLocation {
            points.append(
                DashboardMapPoint(
                    id: "vehicle",
                    title: "Véhicule",
                    coordinate: vehicleCoordinate,
                    tint: .green,
                    symbol: "car.fill"
                )
            )
        }

        return points
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundMap
                LinearGradient(
                    colors: [.black.opacity(0.05), .black.opacity(0.45)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 16) {
                    headerCard
                    Spacer()
                    statusSection
                    actionSection
                    simulationBadge
                }
                .padding()
            }
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
            .onChange(of: appState.currentVehicleLocation.map { "\($0.latitude),\($0.longitude)" }) { _, _ in
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

private extension DashboardView {
    var backgroundMap: some View {
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
                        .background(point.tint.opacity(0.2))
                        .foregroundStyle(point.tint)
                        .clipShape(Circle())
                }
            }
        }
        .ignoresSafeArea()
    }

    var headerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ZOE CarPlay Planner")
                .font(.title.bold())
                .foregroundStyle(.white)
            Text(appState.currentRoute == nil ? "Carte d’accueil avec position du véhicule et accès direct au trajet." : "Le tracé actuel et la position du véhicule restent visibles dès l’ouverture.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder
    var statusSection: some View {
        if let status = appState.vehicleStatus {
            ZStack {
                wallpaperBackground
                Color.black.opacity(0.25)
                VehicleStatusView(status: status, showsMaterialBackground: false)
                    .foregroundStyle(.white)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22))
        } else if appState.isLoading {
            ProgressView("Chargement…")
                .padding()
                .frame(maxWidth: .infinity)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        } else {
            Text("Appuyez sur Actualiser GPS et trajet")
                .foregroundStyle(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
    }

    var actionSection: some View {
        VStack(spacing: 12) {
            NavigationLink {
                RoutePlannerView()
            } label: {
                Label("Planifier un trajet", systemImage: "map.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.blue, in: RoundedRectangle(cornerRadius: 16))
                    .foregroundStyle(.white)
            }

            HStack(spacing: 12) {
                Button {
                    Task {
                        await appState.refreshVehicleStatus()
                        await appState.refreshRouteFromCurrentVehicleLocation()
                    }
                } label: {
                    Label("Actualiser GPS et trajet", systemImage: "location.fill.viewfinder")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.green.opacity(0.2), in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.green)
                }

                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.title3)
                        .frame(width: 54, height: 54)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.white)
                }
            }
        }
    }

    @ViewBuilder
    var simulationBadge: some View {
        if appState.settings.useSimulationMode {
            Label("Mode simulation actif", systemImage: "cpu")
                .font(.caption)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.black.opacity(0.35), in: Capsule())
        }
    }

    @ViewBuilder
    var wallpaperBackground: some View {
        if let filename = appState.settings.dashboardWallpaperFilename,
           let image = DashboardWallpaperStore.image(named: filename) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            LinearGradient(
                colors: [Color.green.opacity(0.35), Color.blue.opacity(0.35)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
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
