# API Renault — Notes techniques

## Référence open-source

Le projet de référence est **hacf-fr/renault-api** :
https://github.com/hacf-fr/renault-api

Ce projet Python documente l'API privée non officielle Renault/MyRenault.

---

## Architecture de l'API

L'API Renault utilise deux systèmes :

### 1. Gigya (authentification)
- Endpoint : `accounts.eu1.gigya.com`
- Mécanisme : login email/password → token JWT

### 2. Kamereon (données véhicule)
- Endpoint : `api-wired-prod-1-euw1.wrd-aws.com`
- Authentification : ****** issu de Gigya
- Versioning : `/commerce/v1`

---

## Endpoints principaux (ZOE II — X102VE)

> ⚠️ Ces endpoints sont privés et non officiels. Ils peuvent changer sans préavis.

| Donnée | Endpoint |
|--------|----------|
| Statut batterie | `GET /accounts/{id}/vehicles/{vin}/battery-status` |
| Localisation | `GET /accounts/{id}/vehicles/{vin}/location` |
| Kilométrage | `GET /accounts/{id}/vehicles/{vin}/cockpit` |
| Réglages charge | `GET /accounts/{id}/vehicles/{vin}/charging-settings` |

---

## Implémentation

### Fichiers concernés

- `RenaultAuthentication.swift` — OAuth2 (TODO)
- `RenaultAPIClient.swift` — Client HTTP
- `RealRenaultVehicleService.swift` — Service réel (TODO)
- `RenaultMapper.swift` — Parsing JSON

### Sécurité

- ❌ Ne jamais stocker email/password/token en clair dans le code
- ✅ Utiliser `KeychainCredentialStore`
- ✅ Prévoir expiration de token et retry

---

## Modèle ZOE II

Pour la ZOE II (ZE50), utiliser le code modèle : **X102VE**

---

## Gestion d'erreurs

L'application ne doit JAMAIS bloquer en cas d'échec Renault :

- Erreur réseau → afficher le dernier état connu
- Token expiré → proposer reconnexion
- Véhicule hors ligne → afficher message
- API modifiée → log d'erreur, fallback simulation
