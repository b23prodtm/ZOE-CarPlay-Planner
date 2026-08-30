# Routage — Guide

## Fournisseurs disponibles

### 1. Apple MapKit (priorité 1 — recommandé)

Fichier : `AppleRoutingProvider.swift`

- ✅ Aucune clé API
- ✅ Fonctionne hors ligne (cartes en cache)
- ✅ Intégration native iOS
- Utilise `MKDirections`

### 2. Mock (priorité 0 — tests)

Fichier : `MockRoutingProvider.swift`

- ✅ Aucune dépendance externe
- ✅ Fonctionne sans réseau
- Distance calculée par formule Haversine × 1.3

### 3. Google Routes API (priorité 3 — optionnel)

Fichier : `GoogleRoutingProvider.swift`

- ❌ Nécessite une clé API Google
- L'application fonctionne sans ce fournisseur

---

## Activer Google Maps

1. Copier `Config.example.swift` → `Config.swift`
2. Renseigner `googleMapsAPIKey`
3. Dans `AppState.swift`, remplacer `AppleRoutingProvider()` par `GoogleRoutingProvider(apiKey: AppConfig.googleMapsAPIKey)`

---

## Ajouter un fournisseur

Implémenter le protocol :

```swift
protocol RoutingProvider: Sendable {
    func calculateRoute(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) async throws -> Route
}
```
