# Architecture — ZOE CarPlay Planner

## Vue d'ensemble

```
ZOECarPlayPlanner/
├── App/
│   ├── ZOECarPlayPlannerApp.swift   # @main, SwiftUI App
│   └── AppState.swift               # ObservableObject — état global
│
├── Models/
│   ├── Vehicle.swift                # Modèle véhicule + ConnectorType
│   ├── BatteryState.swift           # État batterie, ChargingStatus, VehicleStatus
│   ├── Route.swift                  # Route, RoutePoint, RoadTypeDistribution
│   ├── ChargingStop.swift           # ChargingStop, ChargingPlan
│   ├── ChargingStation.swift        # ChargingStation, StationConnector
│   └── PlannerSettings.swift        # Réglages persistants (UserDefaults)
│
├── Services/
│   └── VehicleServiceProtocol.swift # Protocol RenaultVehicleService + erreurs
│
├── Renault/
│   ├── MockRenaultVehicleService.swift  # Simulation complète
│   ├── RealRenaultVehicleService.swift  # TODO: implémentation réelle
│   ├── RenaultAuthentication.swift      # OAuth2 Renault (TODO)
│   └── RenaultAPIClient.swift           # Client HTTP bas-niveau
│
├── Routing/
│   ├── RoutingProvider.swift         # Protocol + RoutingError
│   ├── MockRoutingProvider.swift     # Haversine × 1.3
│   ├── AppleRoutingProvider.swift    # MapKit (MKDirections)
│   └── GoogleRoutingProvider.swift   # Google Routes API (optionnel)
│
├── Charging/
│   ├── ChargingPlanner.swift         # Moteur de planification
│   ├── EnergyConsumptionModel.swift  # Modèle de consommation
│   ├── ChargingStrategy.swift        # Stratégie (min/max SOC, marge)
│   └── ChargingStationProvider.swift # Protocol + Mock
│
├── CarPlay/
│   ├── CarPlaySceneDelegate.swift    # CPTemplateApplicationSceneDelegate
│   └── CarPlayCoordinator.swift      # Templates CarPlay
│
├── Views/
│   ├── ContentView.swift             # TabView principal
│   ├── DashboardView.swift           # Écran d'accueil
│   ├── VehicleStatusView.swift       # Widget état véhicule
│   ├── RoutePlannerView.swift        # Planification trajet
│   ├── ChargingPlanView.swift        # Résultats plan de recharge
│   └── SettingsView.swift            # Réglages
│
└── Utilities/
    ├── SecureStorage.swift           # Keychain (CredentialStore protocol)
    ├── AppError.swift                # Erreur générique
    └── Config.example.swift          # Template de configuration
```

## Flux de données

```
User Input (SwiftUI)
    ↓
AppState (@MainActor, ObservableObject)
    ↓              ↓                ↓
VehicleService  RoutingProvider  ChargingPlanner
(Mock/Real)     (Apple/Mock)     (pur calcul)
    ↓              ↓                ↓
VehicleStatus    Route          ChargingPlan
    ↓              ↓                ↓
              Views + CarPlay
```

## Principes

- **L'application ne doit jamais bloquer** si un service externe est indisponible.
- **Mode simulation** en premier — toujours fonctionnel.
- **Séparation stricte** entre moteur de calcul (Charging/) et interface.
- **Aucun secret** dans le code source.
- **Swift Concurrency** (async/await, actors) partout.
