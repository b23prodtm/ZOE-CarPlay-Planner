# Guide de développement

## Prérequis

- macOS 15 (Sequoia) ou plus récent
- Xcode 16+
- Swift 6.x
- iOS 17+ SDK

---

## Démarrage

```bash
git clone https://github.com/b23prodtm/ZOE-CarPlay-Planner.git
cd ZOE-CarPlay-Planner
open ZOECarPlayPlanner.xcodeproj
```

---

## Configuration locale

```bash
cp ZOECarPlayPlanner/Utilities/Config.example.swift ZOECarPlayPlanner/Utilities/Config.swift
```

Éditer `Config.swift` (jamais committer ce fichier).

---

## Structure des branches

- `main` — code stable
- `copilot/*` — branches de développement Copilot

---

## Ajouter un fournisseur de routage

1. Créer un fichier dans `Routing/`
2. Implémenter `RoutingProvider`
3. Injecter dans `AppState.swift`

---

## Ajouter un fournisseur de bornes

1. Créer un fichier dans `Charging/`
2. Implémenter `ChargingStationProvider`
3. Injecter dans `AppState.planRoute()`

---

## Conventions Swift

- Swift 6 strict concurrency
- `actor` pour les services réseau
- `@MainActor` pour `AppState` et les ViewModels
- Pas de force unwrap (`!`) dans le code de production
- `async throws` pour toutes les opérations asynchrones

---

## Sécurité

- ❌ Jamais de secrets dans le code
- ✅ Keychain pour les tokens
- ✅ `.gitignore` couvre `Config.swift` et les fichiers sensibles
- Voir [RENAULT_API.md](RENAULT_API.md)
