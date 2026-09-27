import SwiftUI
import UIKit

struct DashboardView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // Titre
                Text("ZOE CarPlay Planner")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.primary)

                // Véhicule
                vehicleImageSection

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
                        RoutePlannerView()
                    } label: {
                        DashboardButton(title: "Planifier un trajet", systemImage: "map.fill", color: .blue)
                    }

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
    var vehicleImageSection: some View {
        Group {
            if let filename = appState.settings.dashboardWallpaperFilename,
               let image = DashboardWallpaperStore.image(named: filename) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image("LaunchLogo")
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(maxWidth: 320, minHeight: 180, maxHeight: 220)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .accessibilityLabel("Fond d’écran d’accueil")
        .accessibilityAddTraits(.isImage)
    }
}
