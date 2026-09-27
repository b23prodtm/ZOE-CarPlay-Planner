import SwiftUI
import CoreLocation
import MapKit

struct RoutePlannerView: View {
    @EnvironmentObject var appState: AppState

    @State private var selectedOrigin: TripPlace = Self.defaultOrigin
    @State private var selectedDestination: TripPlace = Self.defaultDestination
    @State private var waypoints: [TripPlace] = []
    @State private var pickerContext: LocationPickerContext?
    @State private var destinationSearchText: String = ""
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 46.4, longitude: 4.7),
        span: MKCoordinateSpan(latitudeDelta: 5.0, longitudeDelta: 5.0)
    )

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

    private var allSuggestions: [TripPlace] {
        var places: [TripPlace] = []
        for place in appState.recentPlaces + knownCities {
            let alreadyExists = places.contains {
                abs($0.latitude - place.latitude) < 0.0001
                && abs($0.longitude - place.longitude) < 0.0001
            }
            if !alreadyExists {
                places.append(place)
            }
        }
        return places
    }

    private var destinationSuggestions: [TripPlace] {
        let query = destinationSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        return allSuggestions
            .filter { $0.name.localizedCaseInsensitiveContains(query) }
            .prefix(6)
            .map { $0 }
    }

    private var mapPoints: [PlannerMapPoint] {
        var points: [PlannerMapPoint] = [
            PlannerMapPoint(
                id: "origin",
                title: "Départ",
                subtitle: selectedOrigin.name,
                coordinate: selectedOrigin.coordinate,
                tint: .blue,
                symbol: "play.circle.fill"
            ),
            PlannerMapPoint(
                id: "destination",
                title: "Destination",
                subtitle: selectedDestination.name,
                coordinate: selectedDestination.coordinate,
                tint: .red,
                symbol: "flag.circle.fill"
            )
        ]

        for (index, waypoint) in waypoints.enumerated() {
            points.append(
                PlannerMapPoint(
                    id: "waypoint-\(waypoint.id.uuidString)",
                    title: "Étape \(index + 1)",
                    subtitle: waypoint.name,
                    coordinate: waypoint.coordinate,
                    tint: .purple,
                    symbol: "point.topleft.down.curvedto.point.bottomright.up"
                )
            )
        }

        for station in appState.availableStationsOnRoute {
            points.append(
                PlannerMapPoint(
                    id: "station-\(station.id.uuidString)",
                    title: station.name,
                    subtitle: station.locationTypeLabel,
                    coordinate: station.coordinate,
                    tint: station.isHighway == true ? .green : .orange,
                    symbol: station.isHighway == true ? "road.lanes" : "bolt.fill"
                )
            )
        }

        return points
    }

    private var mapPointsSignature: String {
        mapPoints
            .map { "\($0.id)-\(Int($0.coordinate.latitude * 10000))-\(Int($0.coordinate.longitude * 10000))" }
            .joined(separator: "|")
    }

    var body: some View {
        NavigationStack {
            Form {
                routeSection
                destinationSearchSection
                preferenceSection
                calculateSection
                loadingSection
                detailedMapSection
                resultSection
                historySection
            }
            .navigationTitle("Planifier un trajet")
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
            .onAppear(perform: updateMapRegion)
            .onChange(of: mapPointsSignature) { _, _ in
                updateMapRegion()
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
                HStack(spacing: 8) {
                    Button {
                        pickerContext = .init(target: .waypoint(waypoint.id))
                    } label: {
                        labeledPlaceRow(title: "Étape \(index + 1)", place: waypoint)
                    }
                    .buttonStyle(.plain)

                    Button {
                        moveWaypoint(at: index, offset: -1)
                    } label: {
                        Image(systemName: "chevron.up")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Monter cette étape")
                    .disabled(index == 0)

                    Button {
                        moveWaypoint(at: index, offset: 1)
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Descendre cette étape")
                    .disabled(index == waypoints.count - 1)

                    Button(role: .destructive) {
                        removeWaypoint(at: index)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Supprimer cette étape")
                }
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
    private var destinationSearchSection: some View {
        Section("Recherche d'arrivée") {
            TextField("Rechercher un lieu d'arrivée", text: $destinationSearchText)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()

            if !destinationSuggestions.isEmpty {
                ForEach(destinationSuggestions) { place in
                    Button {
                        selectedDestination = place
                        destinationSearchText = ""
                    } label: {
                        Label(place.name, systemImage: "magnifyingglass")
                    }
                    .foregroundStyle(.primary)
                }
            }
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
            .accessibilityHint("Le mode Éco réduit la consommation et peut allonger la durée du trajet.")

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
            .disabled(samePlace(selectedOrigin, selectedDestination))

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
    private var detailedMapSection: some View {
        Section("Plan détaillé") {
            Map(coordinateRegion: $mapRegion, annotationItems: mapPoints) { point in
                MapAnnotation(coordinate: point.coordinate) {
                    VStack(spacing: 2) {
                        Image(systemName: point.symbol)
                            .font(.caption)
                            .padding(6)
                            .background(point.tint.opacity(0.15))
                            .foregroundStyle(point.tint)
                            .clipShape(Circle())
                        Text(point.title)
                            .font(.caption2)
                            .lineLimit(1)
                    }
                }
            }
            .frame(height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            if !appState.availableStationsOnRoute.isEmpty {
                Text("Bornes visibles sur la carte : \(appState.availableStationsOnRoute.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(Array(appState.availableStationsOnRoute.prefix(4))) { station in
                    HStack {
                        Label(station.name, systemImage: station.isHighway == true ? "road.lanes" : "bolt.fill")
                        Spacer()
                        Text(station.locationTypeLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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
    private var historySection: some View {
        if !appState.routeHistory.isEmpty {
            Section("Historique des recherches") {
                ForEach(Array(appState.routeHistory.prefix(8))) { trip in
                    Button {
                        selectedOrigin = trip.origin
                        selectedDestination = trip.destination
                        waypoints = trip.waypoints
                        appState.settings.routePreferences = trip.preferences
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

    private func samePlace(_ lhs: TripPlace, _ rhs: TripPlace) -> Bool {
        abs(lhs.latitude - rhs.latitude) < 0.0001
        && abs(lhs.longitude - rhs.longitude) < 0.0001
    }

    private func moveWaypoint(at index: Int, offset: Int) {
        let target = index + offset
        guard waypoints.indices.contains(index), waypoints.indices.contains(target) else { return }
        waypoints.swapAt(index, target)
    }

    private func removeWaypoint(at index: Int) {
        guard waypoints.indices.contains(index) else { return }
        waypoints.remove(at: index)
    }

    private func applySelection(_ place: TripPlace, for target: LocationPickerTarget) {
        switch target {
        case .origin:
            selectedOrigin = place
        case .destination:
            selectedDestination = place
        case .newWaypoint:
            waypoints.append(place)
        case .waypoint(let waypointID):
            guard let index = waypoints.firstIndex(where: { $0.id == waypointID }) else { return }
            waypoints[index] = place
        }
    }

    private func updateMapRegion() {
        guard !mapPoints.isEmpty else { return }

        let latitudes = mapPoints.map { $0.coordinate.latitude }
        let longitudes = mapPoints.map { $0.coordinate.longitude }

        guard let minLat = latitudes.min(),
              let maxLat = latitudes.max(),
              let minLon = longitudes.min(),
              let maxLon = longitudes.max()
        else { return }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let span = MKCoordinateSpan(
            latitudeDelta: max(0.25, (maxLat - minLat) * 1.6),
            longitudeDelta: max(0.25, (maxLon - minLon) * 1.6)
        )

        mapRegion = MKCoordinateRegion(center: center, span: span)
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
    case waypoint(UUID)

    var title: String {
        switch self {
        case .origin:
            return "Choisir le départ"
        case .destination:
            return "Choisir la destination"
        case .newWaypoint:
            return "Ajouter une étape"
        case .waypoint:
            return "Modifier une étape"
        }
    }
}

private struct PlannerMapPoint: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D
    let tint: Color
    let symbol: String
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
                            .accessibilityLabel("Récent : \(place.name)")
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
                        .accessibilityLabel("Ville : \(place.name)")
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
