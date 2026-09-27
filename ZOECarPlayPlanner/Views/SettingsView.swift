import SwiftUI
import PhotosUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedScenario: SimulationScenario = .high

    // Renault login form
    @State private var emailInput: String = ""
    @State private var passwordInput: String = ""
    @State private var vinInput: String = ""
    @State private var showPassword: Bool = false
    @State private var isConnecting: Bool = false
    @State private var selectedWallpaperItem: PhotosPickerItem?
    @State private var wallpaperError: AppError?

    var body: some View {
        NavigationStack {
            Form {
                renaultSection
                simulationSection
                consumptionSection
                chargingStrategySection
                routePreferencesSection
                chargingFilterSection
                navigationSection
                wallpaperSection
                vehicleSection
                saveSection
            }
            .navigationTitle("Réglages")
            .alert("Impossible de mettre à jour le fond d’écran", isPresented: Binding(
                get: { wallpaperError != nil },
                set: { if !$0 { wallpaperError = nil } }
            )) {
                Button("OK") { wallpaperError = nil }
            } message: {
                Text(wallpaperError?.message ?? "")
            }
            .onChange(of: selectedWallpaperItem) { _, newValue in
                guard let newValue else { return }
                Task { await persistWallpaper(from: newValue) }
            }
            .onChange(of: appState.settings.preferredNavigationApp) { _, _ in
                appState.settings.save()
            }
            .onAppear {
                appState.refreshAvailableNavigationApps()
            }
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

            Toggle(
                "Éviter les autoroutes",
                isOn: Binding(
                    get: { appState.settings.routePreferences.avoidHighways },
                    set: { appState.setAvoidHighways($0) }
                )
            )
            .tint(.orange)

            Toggle("Éviter les péages", isOn: $appState.settings.routePreferences.avoidTolls)
                .tint(.orange)

            Toggle(
                "Préférer les autoroutes",
                isOn: Binding(
                    get: { appState.settings.routePreferences.preferHighways },
                    set: { appState.setPreferHighways($0) }
                )
            )
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

    @ViewBuilder private var chargingFilterSection: some View {
        Section("Filtres de recharge par défaut") {
            ForEach(ChargingNetwork.allCases, id: \.self) { network in
                Toggle(network.displayName, isOn: networkBinding(for: network))
                    .tint(.green)
            }

            ForEach(ConnectorType.allCases, id: \.self) { connector in
                Toggle(connector.displayName, isOn: connectorBinding(for: connector))
                    .tint(.blue)
            }
        }
    }

    @ViewBuilder private var navigationSection: some View {
        Section("Navigation externe") {
            Picker("Application préférée", selection: $appState.settings.preferredNavigationApp) {
                ForEach(availableNavigationChoices, id: \.self) { app in
                    Text(app.displayName).tag(app)
                }
            }

            Text("L’application choisie sera utilisée si elle est installée, sinon l’app basculera automatiquement sur Apple Plans.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var wallpaperSection: some View {
        Section("Fond d’écran d’accueil") {
            PhotosPicker(selection: $selectedWallpaperItem, matching: .images) {
                Label("Choisir une image", systemImage: "photo.on.rectangle")
            }

            if appState.settings.dashboardWallpaperFilename != nil {
                Button(role: .destructive) {
                    DashboardWallpaperStore.deleteImage(named: appState.settings.dashboardWallpaperFilename)
                    appState.settings.dashboardWallpaperFilename = nil
                    appState.settings.save()
                } label: {
                    Label("Supprimer le fond personnalisé", systemImage: "trash")
                }
            }

            Text("L’image est stockée localement sur l’iPhone. Si aucune image n’est choisie, le visuel par défaut est utilisé.")
                .font(.caption)
                .foregroundStyle(.secondary)
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

    private func persistWallpaper(from item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw CocoaError(.fileReadUnknown)
            }

            let previousFilename = appState.settings.dashboardWallpaperFilename
            let filename = try DashboardWallpaperStore.saveImageData(data)
            appState.settings.dashboardWallpaperFilename = filename
            if previousFilename != filename {
                DashboardWallpaperStore.deleteImage(named: previousFilename)
            }
            appState.settings.save()
            selectedWallpaperItem = nil
        } catch {
            wallpaperError = AppError.from(error)
        }
    }

    private var availableNavigationChoices: [PreferredNavigationApp] {
        let apps = appState.availableNavigationApps
        return apps.isEmpty ? [.appleMaps] : apps
    }

    private func networkBinding(for network: ChargingNetwork) -> Binding<Bool> {
        Binding(
            get: { appState.settings.selectedChargingNetworks.contains(network) },
            set: { isEnabled in
                appState.settings.setChargingNetwork(network, isEnabled: isEnabled)
            }
        )
    }

    private func connectorBinding(for connector: ConnectorType) -> Binding<Bool> {
        Binding(
            get: { appState.settings.selectedConnectorTypes.contains(connector) },
            set: { isEnabled in
                appState.settings.setConnectorType(connector, isEnabled: isEnabled)
            }
        )
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
