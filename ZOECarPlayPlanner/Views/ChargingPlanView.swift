import SwiftUI

struct ChargingPlanView: View {
    @EnvironmentObject var appState: AppState
    @State private var showNavigationError = false

    var body: some View {
        NavigationStack {
            Group {
                if let plan = appState.chargingPlan, let route = appState.currentRoute {
                    planContent(plan: plan, route: route)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "bolt.car")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        Text("Planifiez d'abord un trajet")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Plan de recharge")
            .alert("Navigation indisponible", isPresented: $showNavigationError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Impossible d'ouvrir Plans et la navigation CarPlay pour ce trajet.")
            }
        }
    }

    @ViewBuilder
    private func planContent(plan: ChargingPlan, route: Route) -> some View {
        List {
            // Résumé
            Section("Résumé") {
                LabeledContent("Trajet", value: route.displayDistance)
                LabeledContent("Recharges prévues", value: "\(plan.numberOfStops)")
                LabeledContent("Batterie à l'arrivée (estimation)", value: plan.displayArrivalSOC)
                if plan.totalExtraTimeMinutes > 0 {
                    LabeledContent("Temps de recharge estimé", value: "≈ \(Int(plan.totalExtraTimeMinutes)) min")
                }

                Picker("Alternative", selection: Binding(
                    get: { appState.chargingStationSelectionPreference },
                    set: { appState.recalculateChargingStops(preference: $0) }
                )) {
                    ForEach(ChargingStationSelectionPreference.allCases, id: \.self) { preference in
                        Text(preference.label).tag(preference)
                    }
                }
                .pickerStyle(.segmented)

                Button {
                    if !appState.openCurrentTripInPreferredNavigationApp(includeChargingStops: true) {
                        showNavigationError = true
                    }
                } label: {
                    Label("Ouvrir dans \(appState.settings.preferredNavigationApp.displayName)", systemImage: "map.fill")
                }
                .foregroundStyle(.blue)
            }

            if plan.stops.isEmpty {
                Section("Trajet direct") {
                    Label("Aucune recharge nécessaire", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            } else {
                Section("Arrêts de recharge") {
                    ForEach(Array(plan.stops.enumerated()), id: \.element.id) { index, stop in
                        ChargingStopRow(
                            stop: stop,
                            index: index + 1,
                            selectedStation: appState.selectedStation(for: stop),
                            stationOptions: appState.stationOptions(for: stop),
                            onSelectStation: { station in
                                appState.selectStation(station, for: stop)
                            }
                        )
                    }
                }
            }

            // Avertissement
            Section {
                Label("Les durées et niveaux indiqués sont des estimations.", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - ChargingStopRow

struct ChargingStopRow: View {
    let stop: ChargingStop
    let index: Int
    let selectedStation: ChargingStation?
    let stationOptions: [ChargingStation]
    let onSelectStation: (ChargingStation) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recharge \(index)")
                .font(.headline)
                .foregroundStyle(.orange)

            HStack {
                Label("À \(Int(stop.distanceFromOriginKm)) km", systemImage: "road.lanes")
                Spacer()
                Label(stop.displayArrivalSOC, systemImage: "battery.25percent")
                    .foregroundStyle(.red)
            }
            .font(.subheadline)

            HStack {
                Label("→ \(stop.displayTargetSOC)", systemImage: "battery.75percent")
                    .foregroundStyle(.green)
                Spacer()
                Label(stop.displayDuration, systemImage: "clock")
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)

            if let selectedStation {
                Label(selectedStation.name, systemImage: "bolt.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if stationOptions.count > 1 {
                    Menu {
                        ForEach(stationOptions) { station in
                            Button {
                                onSelectStation(station)
                            } label: {
                                Label(
                                    "\(station.name) • \(station.displayPower)",
                                    systemImage: station.id == selectedStation.id ? "checkmark.circle.fill" : "circle"
                                )
                            }
                        }
                    } label: {
                        Label("Changer de borne", systemImage: "arrow.triangle.swap")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.blue)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
