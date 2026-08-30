# CarPlay Simulator — Guide

## Lancer l'application

1. Ouvrir Xcode
2. Sélectionner un simulateur iPhone (iOS 17+)
3. `⌘R` — lancer l'application

---

## Lancer le simulateur CarPlay

1. Dans le simulateur iPhone, ouvrir **I/O** → **External Displays** → **CarPlay**
2. Une fenêtre CarPlay séparée apparaît
3. L'application doit apparaître dans la liste CarPlay

---

## Tester une destination

1. Dans l'app iPhone, onglet **Trajet**
2. Sélectionner une destination (ex: Genève, Paris)
3. Appuyer sur la destination pour calculer
4. Le plan de recharge apparaît dans l'interface CarPlay

---

## Modifier le SOC (State of Charge)

1. Onglet **Réglages** → **Mode simulation** → activé
2. Choisir un scénario prédéfini :
   - Batterie 100 % / 80 % / 50 % / 20 %
   - Véhicule en charge
   - Véhicule non connecté
3. Ou utiliser le slider **SOC personnalisé**
4. Appuyer sur **Actualiser** dans l'écran principal

---

## Simuler une recharge

1. Aller dans **Réglages** → **Mode simulation**
2. Sélectionner le scénario **Véhicule en charge**
3. L'écran principal affiche la puissance de charge
4. CarPlay affiche l'état **En charge**

---

## Notes importantes

- Les entitlements CarPlay ne sont pas requis pour le simulateur
- En production, un entitlement Apple est nécessaire
- Le simulateur CarPlay est disponible dans Xcode depuis la version 12
