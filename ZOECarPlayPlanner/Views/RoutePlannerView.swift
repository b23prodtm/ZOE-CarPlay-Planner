import SwiftUI
import CoreLocation

struct RoutePlannerView: View {
    @EnvironmentObject var appState: AppState

    @State private var selectedOrigin: TripPlace = Self.defaultOrigin
    @State private var selectedDestination: TripPlace = Self.defaultDestination
    @State private var waypoints: [TripPlace] = []
    @State private var pickerContext: LocationPickerContext?

    private static let defaultOrigin = TripPlace(
        name: "Lyon",
        coordinate: CLLocationCoordinate2D(latitude: 45.7640, longitude: 4.8357)
    )
    private static let defaultDestination = TripPlace(
        name: "Genève",
        coordinate: CLLocationCoordinate2D(latitude: 46.2044, longitude: 6.1432)
    )

    private let knownCities: [TripPlace] = [
        TripPlace(name: "Lyon", coordinate: CLLocationCoordinate2D(latitude: 45.7640, longitude: 4.8357)),
        TripPlace(name: "Paris", coordinate: CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522)),
        TripPlace(name: "Marseille", coordinate: CLLocationCoordinate2D(latitude: 43.2965, longitude: 5.3698)),
        TripPlace(name: "Bordeaux", coordinate: CLLocationCoordinate2D(latitude: 44.8378, longitude: -0.5792)),
        TripPlace(name: "Nantes", coordinate: CLLocationCoordinate2D(latitude: 47.2184, longitude: -1.5536)),
        TripPlace(name: "Toulouse", coordinate: CLLocationCoordinate2D(latitude: 43.6047, longitude: 1.4442)),
        TripPlace(name: "Lille", coordinate: CLLocationCoordinate2D(latitude: 50.6292, longitude: 3.0573)),
        TripPlace(name: "Genève", coordinate: CLLocationCoordinate2D(latitude: 46.2044, longitude: 6.1432)),
        TripPlace(name: "Lausanne", coordinate: CLLocationCoordinate2D(latitude: 46.5197, longitude: 6.6323)),
        TripPlace(name: "Turin", coordinate: CLLocationCoordinate2D(latitude: 45.0703, longitude: 7.6869))
    ]

    var body: some View {
        NavigationStack {
            Form {
                routeSection
                preferenceSection
                calculateSection
                loadingSection
                resultSection
                recentPlacesSection
                historySection
            }
            .navigationTitle("Planifier un trajet")
            .toolbar { EditButton() }
            .sheet(item: $pickerContext) { context in
                LocationPickerSheet(
                    title: context.target.title,
                    knownCities: knownCities,
                    recentPlaces: appState.recentPlaces,
                    onSelect: { place in
                        applySelection(place, for: context.target)
                    }
                )
            }
        }
    }

    @ViewBuilder
    private var routeSection: some View {
        Section("Trajet") {
            Button {
                pickerContext = .init(target: .origin)
            } label: {
                labeledPlaceRow(title: "Départ", place: selectedOrigin)
            }
            .foregroundStyle(.primary)

            Button {
                pickerContext = .init(target: .destination)
            } label: {
                labeledPlaceRow(title: "Destination", place: selectedDestination)
            }
            .foregroundStyle(.primary)

            ForEach(Array(waypoints.enumerated()), id: \.element.id) { index, waypoint in
                Button {
                    pickerContext = .init(target: .waypoint(index))
                } label: {
                    labeledPlaceRow(title: "Étape \(index + 1)", place: waypoint)
                }
                .foregroundStyle(.primary)
            }
            .onDelete { offsets in
                waypoints.remove(atOffsets: offsets)
            }
            .onMove { source, destination in
                waypoints.move(fromOffsets: source, toOffset: destination)
            }

            Button {
                pickerContext = .init(target: .newWaypoint)
            } label: {
                Label("Ajouter une étape", systemImage: "plus.circle")
            }
            .foregroundStyle(.blue)
        }
    }

    @ViewBuilder
    private var preferenceSection: some View {
        Section("Mode et préférences") {
            Picker("Mode", selection: $appState.settings.routePreferences.mode) {
                ForEach(TravelMode.allCases, id: \.self) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Toggle("Éviter les autoroutes", isOn: $appState.settings.routePreferences.avoidHighways)
                .tint(.orange)
            Toggle("Éviter les péages", isOn: $appState.settings.routePreferences.avoidTolls)
                .tint(.orange)
            Toggle("Préférer les autoroutes", isOn: $appState.settings.routePreferences.preferHighways)
                .tint(.green)
            Toggle("Préférer les routes pittoresques", isOn: $appState.settings.routePreferences.preferScenic)
                .tint(.purple)
        }
    }

    @ViewBuilder
    private var calculateSection: some View {
        Section {
            Button {
                Task {
                    await appState.planTrip(
                        origin: selectedOrigin,
                        destination: selectedDestination,
                        waypoints: waypoints
                    )
                }
            } label: {
                Label("Calculer le trajet", systemImage: "arrow.triangle.branch")
            }
            .disabled(selectedOrigin.id == selectedDestination.id)

            if appState.settings.routePreferences != RoutePreferences() {
                Label(appState.settings.routePreferences.summaryText, systemImage: "leaf")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var loadingSection: some View {
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
    }

    @ViewBuilder
    private var resultSection: some View {
        if let route = appState.currentRoute {
            Section("Résultat") {
                LabeledContent("Distance", value: route.displayDistance)
                LabeledContent("Durée estimée", value: "\(Int(route.estimatedDurationMinutes)) min")
                if !route.waypoints.isEmpty {
                    LabeledContent("Étapes", value: "\(route.waypoints.count)")
                }
            }

            if !route.waypoints.isEmpty {
                Section("Ordre des étapes") {
                    ForEach(route.waypoints) { point in
                        Label(point.name, systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var recentPlacesSection: some View {
        if !appState.recentPlaces.isEmpty {
            Section("Lieux récents") {
                ForEach(Array(appState.recentPlaces.prefix(5))) { place in
                    Button {
                        selectedDestination = place
                    } label: {
                        Label(place.name, systemImage: "clock.arrow.circlepath")
                    }
                    .foregroundStyle(.primary)
                }
            }
        }
    }

    @ViewBuilder
    private var historySection: some View {
        if !appState.routeHistory.isEmpty {
            Section("Historique des recherches") {
                ForEach(Array(appState.routeHistory.prefix(8))) { trip in
                    Button {
                        selectedOrigin = trip.origin
                        selectedDestination = trip.destination
                        waypoints = trip.waypoints
                        Task {
                            await appState.relaunchTripFromHistory(trip)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(trip.summary)
                                .foregroundStyle(.primary)
                            Text(trip.preferences.summaryText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func labeledPlaceRow(title: String, place: TripPlace) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(place.name)
                .foregroundStyle(.secondary)
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private func applySelection(_ place: TripPlace, for target: LocationPickerTarget) {
        switch target {
        case .origin:
            selectedOrigin = place
        case .destination:
            selectedDestination = place
        case .newWaypoint:
            waypoints.append(place)
        case .waypoint(let index):
            guard waypoints.indices.contains(index) else { return }
            waypoints[index] = place
        }
    }
}

private struct LocationPickerContext: Identifiable {
    let id = UUID()
    let target: LocationPickerTarget
}

private enum LocationPickerTarget {
    case origin
    case destination
    case newWaypoint
    case waypoint(Int)

    var title: String {
        switch self {
        case .origin:
            return "Choisir le départ"
        case .destination:
            return "Choisir la destination"
        case .newWaypoint:
            return "Ajouter une étape"
        case .waypoint(let index):
            return "Modifier l'étape \(index + 1)"
        }
    }
}

private struct LocationPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let knownCities: [TripPlace]
    let recentPlaces: [TripPlace]
    let onSelect: (TripPlace) -> Void

    @State private var searchText: String = ""

    private var filteredCities: [TripPlace] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return knownCities
        }

        return knownCities.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if !recentPlaces.isEmpty {
                    Section("Récents") {
                        ForEach(recentPlaces) { place in
                            Button(place.name) {
                                onSelect(place)
                                dismiss()
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }

                Section("Villes") {
                    ForEach(filteredCities) { place in
                        Button(place.name) {
                            onSelect(place)
                            dismiss()
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Rechercher une ville")
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }
}
