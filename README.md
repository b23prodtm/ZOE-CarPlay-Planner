# ZOE CarPlay Planner

Application iPhone pour planifier les trajets d'une **Renault ZOE ZE50 R110** avec interface CarPlay.

---

## Fonctionnalités

- 🔋 État de la batterie en temps réel (ou simulation)
- 🗺️ Planification de trajet avec Apple Maps
- ⚡ Calcul automatique des arrêts de recharge
- 🚗 Interface CarPlay dédiée
- 🔒 Mode simulation — aucun compte Renault requis

---

## Installation

### Pré-requis

- macOS 15+ avec Xcode 16+
- iOS 17+ simulator ou device
- Swift 6.x

### Ouvrir dans Xcode

```bash
open ZOECarPlayPlanner.xcodeproj
```

---

## Lancement

### Simulateur iPhone

1. Sélectionner le scheme `ZOECarPlayPlanner`
2. Choisir un simulateur iPhone
3. `⌘R` pour lancer

### Mode simulation

L'application démarre directement en **mode simulation** (pas de compte Renault nécessaire).

Dans l'onglet **Réglages** → **Mode simulation** → activer/désactiver.

Scénarios disponibles :
- Batterie 100 %
- Batterie 80 %
- Batterie 50 %
- Batterie 20 %
- Véhicule en charge
- Véhicule non connecté

---

## CarPlay

Voir [CARPLAY.md](CARPLAY.md) et [CARPLAY_SIMULATOR.md](CARPLAY_SIMULATOR.md).

---

## Apple Maps

Intégré via `AppleRoutingProvider` (MapKit). Aucune clé API requise.

---

## Google Maps (optionnel)

Voir [ROUTING.md](ROUTING.md).

Copier `Config.example.swift` → `Config.swift` et renseigner `googleMapsAPIKey`.

---

## Connecter une vraie ZOE

1. Obtenir un compte développeur Renault/MyRenault
2. Implémenter `RealRenaultVehicleService` (voir [RENAULT_API.md](RENAULT_API.md))
3. Stocker les credentials via `KeychainCredentialStore`
4. Dans les réglages : désactiver le mode simulation

---

## Lancer les tests

```bash
# Dans Xcode : ⌘U
# En ligne de commande :
xcodebuild test -scheme ZOECarPlayPlanner -destination 'platform=iOS Simulator,name=iPhone 16'
```

---

## Structure du projet

```
ZOECarPlayPlanner/
├── App/            # Entry point, AppState
├── Models/         # Vehicle, BatteryState, Route, ChargingStop…
├── Services/       # Protocols
├── Renault/        # MockRenaultVehicleService, RealRenaultVehicleService
├── Routing/        # RoutingProvider, Apple, Google, Mock
├── Charging/       # ChargingPlanner, EnergyConsumptionModel
├── CarPlay/        # CarPlaySceneDelegate, CarPlayCoordinator
├── Views/          # SwiftUI views
└── Utilities/      # SecureStorage, AppError, Config
ZOECarPlayPlannerTests/
```

---

## Licence

Voir [LICENSE](LICENSE).
