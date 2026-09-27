# CarPlay — Guide d'intégration

## Vue d'ensemble

L'intégration CarPlay utilise `CPTemplateApplicationScene` (iOS 14+).

---

## Entitlement requis

> ⚠️ L'entitlement CarPlay nécessite une approbation Apple.
> Ne pas inventer d'entitlement valide dans le code.

Pour une application de **navigation** :
```
com.apple.developer.carplay-navigation
```

Pour une application d'**information** :
```
com.apple.developer.carplay-information
```

Demander l'accès sur : https://developer.apple.com/carplay/

---

## Configuration Info.plist

```xml
<key>UIApplicationSceneManifest</key>
<dict>
    <key>UISceneConfigurations</key>
    <dict>
        <key>CPTemplateApplicationSceneSessionRoleApplication</key>
        <array>
            <dict>
                <key>UISceneClassName</key>
                <string>CPTemplateApplicationScene</string>
                <key>UISceneDelegateClassName</key>
                <string>$(PRODUCT_MODULE_NAME).CarPlaySceneDelegate</string>
                <key>UISceneConfigurationName</key>
                <string>CarPlay Configuration</string>
            </dict>
        </array>
    </dict>
</dict>
```

---

## Templates utilisés

| Template | Usage |
|----------|-------|
| `CPListTemplate` | Écran principal, liste des recharges |
| `CPInformationTemplate` | État du véhicule |
| `CPSearchTemplate` | Recherche de destination (futur) |
| `CPMapTemplate` | Navigation (futur, nécessite entitlement nav) |

---

## Fichiers

- `CarPlaySceneDelegate.swift` — Connexion/déconnexion CarPlay
- `CarPlayCoordinator.swift` — Gestion des templates

---

## Sécurité

- L'interface CarPlay doit rester **simple et non distractive**
- Gros texte, peu d'interactions
- Aucune action complexe pendant la conduite
