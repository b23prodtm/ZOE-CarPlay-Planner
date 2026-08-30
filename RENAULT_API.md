# API Renault — Notes techniques

## Référence open-source

Le projet de référence est **hacf-fr/renault-api** :
https://github.com/hacf-fr/renault-api

Ce projet Python documente l'API privée non officielle Renault/MyRenault (Kamereon).

---

## Flux d'authentification implémenté

```
1. POST Gigya accounts.login (email + password)
        ↓  login_token (cookieValue)

2. POST Gigya accounts.getJWT (login_token)
        ↓  id_token (JWT, durée 900 s)

3. POST Kamereon /commerce/v1/persons/token (id_token)
        ↓  accessToken + accountId

4. GET/POST Kamereon /commerce/v1/accounts/{accountId}/vehicles/{vin}/...
        ← données véhicule
```

**Fichiers concernés :**
- `RenaultAuthentication.swift` — flux Gigya + Kamereon token
- `RenaultAPIClient.swift` — requêtes GET/POST avec headers complets
- `SecureStorage.swift` — email, password, accountId, VIN → Keychain uniquement

---

## Endpoints implémentés

| Donnée | Méthode | Path Kamereon |
|--------|---------|---------------|
| État batterie | GET | `/accounts/{id}/vehicles/{vin}/battery-status?type=json` |
| Localisation | GET | `/accounts/{id}/vehicles/{vin}/location` |
| Statut charge | GET | `/accounts/{id}/vehicles/{vin}/charging-settings` |
| Kilométrage | GET | `/accounts/{id}/vehicles/{vin}/cockpit?type=json` |

---

## Headers Kamereon requis

| Header | Valeur |
|--------|--------|
| `Authorization` | `****** |
| `x-api-key` | `oF09WnKqvBDcrQzcW1rJ70D1nsB_AZkbTIKSxE_8JA8w` (clé publique Renault EU) |
| `x-brand-id` | `RENAULT` |
| `x-kamereon-locale` | `fr_FR` |
| `Accept` | `application/json` |

---

## Clés Gigya (publiques, non secrètes)

| Usage | Clé |
|-------|-----|
| Gigya API Key Renault EU | `3_e8d4g4SE_Fo8ahyHwwP21pqT2Z6L18MWbCK1DgDcXZ8cbOKe5n` |

> Ces clés sont **publiques** (incluses dans l'app Renault) et ne constituent pas des secrets.
> Elles ne donnent pas accès aux données d'un utilisateur sans email + mot de passe.

---

## Structure réponse JSON — battery-status

```json
{
  "data": {
    "type": "Car",
    "attributes": {
      "timestamp": "2024-01-15T10:30:00+01:00",
      "batteryLevel": 82,
      "batteryAutonomy": 245,
      "batteryAvailableEnergy": 41,
      "plugStatus": 1,
      "chargingStatus": 1.0,
      "chargingInstantaneousPower": 7400,
      "chargingRemainingTime": 35
    }
  }
}
```

`chargingStatus` : `-1.0` = non en charge, `0.1` = connecté en attente, `1.0` = en charge

---

## Modèle ZOE II

Pour la ZOE II (ZE50), utiliser le code modèle : **X102VE**

---

## Sécurité

- ❌ Email, mot de passe, token → jamais dans le code
- ✅ `KeychainCredentialStore` — Keychain iOS uniquement
- ✅ Token en mémoire uniquement, durée 900 s avec marge 30 s
- ✅ `clearCredentials()` efface tout du Keychain et de la mémoire

---

## Gestion d'erreurs

L'application ne bloque JAMAIS en cas d'échec Renault :

| Erreur | Comportement |
|--------|-------------|
| Réseau indisponible | Afficher dernier état connu |
| Token expiré | Ré-authentification automatique |
| Véhicule hors ligne | Message `vehicleOffline` |
| API Renault modifiée | Log d'erreur, fallback simulation |
| Timeout | Message `timeout`, retry manuel |

---

## Activer la connexion réelle

1. Dans l'app : onglet **Réglages** → **Compte Renault**
2. Saisir email MyRenault + mot de passe + VIN
3. L'app se connecte, désactive le mode simulation et utilise les données réelles
4. Les credentials sont stockés dans le Keychain de l'iPhone, jamais en clair

