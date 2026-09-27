# Tests — Guide

## Lancer les tests

### Dans Xcode
`⌘U` pour lancer tous les tests.

### En ligne de commande
```bash
xcodebuild test \
  -scheme ZOECarPlayPlanner \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -resultBundlePath TestResults.xcresult
```

---

## Couverture de tests

### ChargingPlannerTests
- ✅ Batterie 100 %
- ✅ Batterie 80 %
- ✅ Batterie 50 %
- ✅ Batterie 20 %
- ✅ Trajet < autonomie (pas de recharge)
- ✅ Trajet nécessitant 1 recharge
- ✅ Trajet nécessitant 2+ recharges
- ✅ Trajet très long (protection boucle infinie)
- ✅ Marge de sécurité
- ✅ Consommation différente
- ✅ SOC arrivée jamais négatif
- ✅ Durée de recharge positive

### EnergyConsumptionTests
- ✅ Consommation pondérée (mixte, autoroute, ville)
- ✅ Override consommation utilisateur
- ✅ Calcul énergie kWh

### MockRoutingTests
- ✅ Distance Lyon → Genève raisonnable
- ✅ Distance Lyon → Paris raisonnable
- ✅ Même départ/arrivée → distance ≈ 0
- ✅ Durée positive
- ✅ Coordonnées préservées

### MockVehicleServiceTests
- ✅ Tous les scénarios de simulation
- ✅ SOC personnalisé
- ✅ Véhicule non connecté → pas de localisation
- ✅ Scénario charge → isCharging = true

---

## Écrire un test

Les tests sont dans `ZOECarPlayPlannerTests/`.

Utiliser `XCTest` et `@testable import ZOECarPlayPlanner`.

Le `ChargingPlanner` est un `struct` — instanciation directe, pas de mock requis.
