import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedScenario: SimulationScenario = .high

    var body: some View {
        NavigationStack {
            Form {
                // Mode simulation
                Section("Mode simulation") {
                    Toggle("Activer le mode simulation", isOn: $appState.settings.useSimulationMode)
                        .tint(.orange)

                    if appState.settings.useSimulationMode {
                        Picker("Scénario", selection: $selectedScenario) {
                            ForEach(SimulationScenario.allCases) { scenario in
                                Text(scenario.rawValue).tag(scenario)
                            }
                        }
                        .onChange(of: selectedScenario) { _, new in
                            Task {
                                await appState.refreshVehicleStatus()
                            }
                        }
                    }
                }

                // Consommation
                Section("Consommation") {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Consommation")
                            Spacer()
                            Text("\(Int(appState.settings.consumptionWhPerKm)) Wh/km")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $appState.settings.consumptionWhPerKm, in: 100...300, step: 5)
                            .tint(.green)
                    }
                }

                // Stratégie de recharge
                Section("Stratégie de recharge") {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Batterie minimale à l'arrivée")
                            Spacer()
                            Text("\(Int(appState.settings.minBatteryAtArrivalPercent)) %")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $appState.settings.minBatteryAtArrivalPercent, in: 5...30, step: 1)
                            .tint(.orange)
                    }

                    VStack(alignment: .leading) {
                        HStack {
                            Text("SOC cible après recharge")
                            Spacer()
                            Text("\(Int(appState.settings.maxBatteryAfterChargePercent)) %")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $appState.settings.maxBatteryAfterChargePercent, in: 50...100, step: 5)
                            .tint(.green)
                    }

                    VStack(alignment: .leading) {
                        HStack {
                            Text("Marge de sécurité")
                            Spacer()
                            Text("\(Int(appState.settings.safetyMarginPercent)) %")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $appState.settings.safetyMarginPercent, in: 0...20, step: 1)
                            .tint(.blue)
                    }
                }

                // Véhicule
                Section("Véhicule") {
                    LabeledContent("Modèle", value: appState.settings.vehicle.model)
                    LabeledContent("Batterie utilisable", value: "\(appState.settings.vehicle.usableBatteryKWh, specifier: "%.0f") kWh")
                }

                // Sauvegarde
                Section {
                    Button("Enregistrer les réglages") {
                        appState.settings.save()
                    }
                    .foregroundStyle(.green)
                }
            }
            .navigationTitle("Réglages")
        }
    }
}
