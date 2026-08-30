import SwiftUI
import CoreLocation

struct RoutePlannerView: View {
    @EnvironmentObject var appState: AppState
    @State private var destinationText = ""
    @State private var isCalculating = false

    // Coordonnées prédéfinies pour la démo
    private let presets: [(name: String, coord: CLLocationCoordinate2D)] = [
        ("Genève",  CLLocationCoordinate2D(latitude: 46.2044, longitude: 6.1432)),
        ("Paris",   CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522)),
        ("Marseille", CLLocationCoordinate2D(latitude: 43.2965, longitude: 5.3698)),
        ("Bordeaux",  CLLocationCoordinate2D(latitude: 44.8378, longitude: -0.5792))
    ]

    private let origin = CLLocationCoordinate2D(latitude: 45.7640, longitude: 4.8357) // Lyon

    var body: some View {
        NavigationStack {
            Form {
                Section("Départ") {
                    Label("Lyon (simulation)", systemImage: "mappin.circle.fill")
                        .foregroundStyle(.blue)
                }

                Section("Destination") {
                    ForEach(presets, id: \.name) { preset in
                        Button {
                            destinationText = preset.name
                            Task { await calculate(to: preset.coord) }
                        } label: {
                            HStack {
                                Text(preset.name)
                                Spacer()
                                if destinationText == preset.name {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }

                if appState.isLoading {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Calcul en cours…")
                                .foregroundStyle(.secondary)
                                .padding(.leading, 8)
                        }
                    }
                }

                if let route = appState.currentRoute {
                    Section("Résultat") {
                        LabeledContent("Distance", value: route.displayDistance)
                        LabeledContent("Durée estimée", value: "\(Int(route.estimatedDurationMinutes)) min")
                    }
                }
            }
            .navigationTitle("Planifier un trajet")
        }
    }

    private func calculate(to destination: CLLocationCoordinate2D) async {
        await appState.planRoute(from: origin, to: destination)
    }
}
