import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Accueil", systemImage: "car.fill") }

            RoutePlannerView()
                .tabItem { Label("Trajet", systemImage: "map.fill") }

            ChargingPlanView()
                .tabItem { Label("Recharge", systemImage: "bolt.car.fill") }

            SettingsView()
                .tabItem { Label("Réglages", systemImage: "gearshape.fill") }
        }
        .tint(.green)
    }
}
