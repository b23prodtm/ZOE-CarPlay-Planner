import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedScenario: SimulationScenario = .high

    // Renault login form
    @State private var emailInput: String = ""
    @State private var passwordInput: String = ""
    @State private var vinInput: String = ""
    @State private var showPassword: Bool = false
    @State private var isConnecting: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                renaultSection
                simulationSection
                consumptionSection
                chargingStrategySection
                routePreferencesSection
                vehicleSection
                saveSection
            }
            .navigationTitle("Réglages")
        }
    }

    @ViewBuilder private var renaultSection: some View {
        Section {
            if appState.isAuthenticated {
                authenticatedRow
            } else {
                loginForm
            }
        } header: {
            Label("Compte Renault / MyRenault", systemImage: "person.badge.key.fill")
        }
    }

    @ViewBuilder private var simulationSection: some View {
        Section("Mode simulation") {
            Toggle("Activer le mode simulation", isOn: $appState.settings.useSimulationMode)
                .tint(.orange)
            if appState.settings.useSimulationMode {
                Picker("Scénario", selection: $selectedScenario) {
                    ForEach(SimulationScenario.allCases) { scenario in
                        Text(scenario.rawValue).tag(scenario)
                    }
                }
                .onChange(of: selectedScenario) { _, _ in
                    Task { await appState.refreshVehicleStatus() }
                }
            }
        }
    }

    @ViewBuilder private var consumptionSection: some View {
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
    }

    @ViewBuilder private var chargingStrategySection: some View {
        Section("Stratégie de recharge") {
            socSlider(label: "Batterie minimale à l'arrivée",
                      value: $appState.settings.minBatteryAtArrivalPercent,
                      range: 5...30, tint: .orange)
            socSlider(label: "SOC cible après recharge",
                      value: $appState.settings.maxBatteryAfterChargePercent,
                      range: 50...100, tint: .green)
            socSlider(label: "Marge de sécurité",
                      value: $appState.settings.safetyMarginPercent,
                      range: 0...20, tint: .blue)
        }
    }
    
    @ViewBuilder private var routePreferencesSection: some View {
        Section("Préférences de trajet") {
            Picker("Mode", selection: $appState.settings.routePreferences.mode) {
                ForEach(TravelMode.allCases, id: \.self) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityHint("Le mode Éco réduit la consommation et peut rallonger le trajet.")

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
    
    @ViewBuilder private var vehicleSection: some View {
        Section("Véhicule") {
            HStack {
                Text("Modèle")
                Spacer()
                Text(appState.settings.vehicle.model)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("Batterie utilisable")
                Spacer()
                Text(String(format: "%.0f kWh", appState.settings.vehicle.usableBatteryKWh))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var saveSection: some View {
        Section {
            Button("Enregistrer les réglages") {
                appState.settings.save()
            }
            .foregroundStyle(.green)
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var authenticatedRow: some View {
        HStack {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.green)
            VStack(alignment: .leading) {
                Text("Connecté à MyRenault")
                    .font(.headline)
                Text("Mode réel actif")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Déconnecter") {
                Task {
                    await appState.disconnectRenault()
                }
                emailInput = ""
                passwordInput = ""
                vinInput = ""
            }
            .foregroundStyle(.red)
            .font(.subheadline)
        }
    }

    @ViewBuilder
    private var loginForm: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Email MyRenault")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("email@example.com", text: $emailInput)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }

        VStack(alignment: .leading, spacing: 4) {
            Text("Mot de passe")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                if showPassword {
                    TextField("Mot de passe", text: $passwordInput)
                        .textContentType(.password)
                } else {
                    SecureField("Mot de passe", text: $passwordInput)
                        .textContentType(.password)
                }
                Button {
                    showPassword.toggle()
                } label: {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
            }
        }

        VStack(alignment: .leading, spacing: 4) {
            Text("VIN du véhicule (numéro de châssis)")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("VF1XXXXXXXXXXXXX", text: $vinInput)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.characters)
        }

        Button {
            Task { await connect() }
        } label: {
            if isConnecting {
                HStack {
                    ProgressView()
                    Text("Connexion…").padding(.leading, 6)
                }
            } else {
                Label("Se connecter à MyRenault", systemImage: "bolt.car.fill")
            }
        }
        .disabled(emailInput.isEmpty || passwordInput.isEmpty || vinInput.isEmpty || isConnecting)
        .foregroundStyle(.blue)

        Text("Vos identifiants sont stockés uniquement dans le Keychain de votre iPhone.")
            .font(.caption2)
            .foregroundStyle(.secondary)
    }

    private func connect() async {
        isConnecting = true
        defer { isConnecting = false }
        await appState.connectRenault(
            email: emailInput.trimmingCharacters(in: .whitespaces),
            password: passwordInput,
            vin: vinInput.trimmingCharacters(in: .whitespaces).uppercased()
        )
        if appState.isAuthenticated {
            passwordInput = ""   // Effacer le mot de passe de la mémoire vive
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func socSlider(label: String, value: Binding<Double>, range: ClosedRange<Double>, tint: Color) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(label)
                Spacer()
                Text("\(Int(value.wrappedValue)) %")
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: 1)
                .tint(tint)
        }
    }
}
