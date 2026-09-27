import Foundation

// MARK: - RenaultAuthentication
//
// Flux d'authentification basé sur la référence open-source :
// https://github.com/hacf-fr/renault-api
//
// Étapes :
//   1. POST Gigya loginID/password  → gigyaToken (login_token)
//   2. POST Gigya getJWT            → gigyaJWT
//   3. POST Kamereon /persons/token → kamereonToken + accountId
//   4. Toutes les requêtes API Renault utilisent le kamereonToken.
//
// La config serveur (endpoints + clés API Gigya/Kamereon) est récupérée
// dynamiquement plutôt que codée en dur, car Renault fait tourner ces
// clés sans préavis côté serveur (cf. historique hacf-fr/renault-api).
// Source du endpoint de config : evcc-io/evcc (vehicle/renault.go)
//
// Les credentials (email, password) ne sont stockés que dans le Keychain.
// Les tokens et la config serveur sont conservés en mémoire uniquement
// et jamais persistés.

actor RenaultAuthentication {
    private let credentialStore: CredentialStore
    private let session: URLSession
    private var cachedToken: RenaultToken?
    private var cachedServerConfig: RenaultServerConfig?

    // Région utilisée pour récupérer la config serveur.
    private static let region = "FR"
    private static let configURL =
        "https://renault-wrd-prod-1-euw1-myrapp-one.s3-eu-west-1.amazonaws.com/configuration/android/config_\(region).json"

    init(credentialStore: CredentialStore = KeychainCredentialStore(),
         session: URLSession = .shared) {
        self.credentialStore = credentialStore
        self.session = session
    }

    // MARK: - Public API

    /// Retourne un token Kamereon valide (depuis le cache ou par authentification).
    func validToken() async throws -> RenaultToken {
        if let token = cachedToken, !token.isExpired {
            return token
        }
        let email    = try credentialStore.retrieve(forKey: "renault_email")
        let password = try credentialStore.retrieve(forKey: "renault_password")
        let token = try await authenticate(email: email, password: password)
        cachedToken = token
        return token
    }

    /// Stocke les credentials dans le Keychain et vérifie l'authentification.
    func storeCredentials(email: String, password: String) async throws {
        try credentialStore.store(value: email, forKey: "renault_email")
        try credentialStore.store(value: password, forKey: "renault_password")
        // Vérification immédiate
        let token = try await authenticate(email: email, password: password)
        cachedToken = token
    }

    /// Efface les credentials du Keychain et invalide le token en mémoire.
    func clearCredentials() {
        try? credentialStore.delete(forKey: "renault_email")
        try? credentialStore.delete(forKey: "renault_password")
        cachedToken = nil
    }

    var hasCredentials: Bool {
        (try? credentialStore.retrieve(forKey: "renault_email")) != nil
    }

    /// Expose le endpoint + clé Kamereon à jour pour RenaultAPIClient.
    func kamereonServerInfo() async throws -> (base: String, apiKey: String) {
        let config = try await serverConfig()
        return (config.servers.wiredProd.target, config.servers.wiredProd.apikey)
    }

    /// Invalide token ET config serveur — à appeler après un échec d'auth
    /// (401/403) avant de retenter, pour couvrir clé API rotée ET token expiré.
    func invalidateSession() {
        cachedToken = nil
        cachedServerConfig = nil
    }

    /// Invalide uniquement la config serveur (clés API), garde le token.
    /// Sous-cas de invalidateSession(), gardé disponible séparément si besoin.
    func forceServerConfigRefresh() {
        cachedServerConfig = nil
    }

    // MARK: - Server config

    /// Récupère (et met en cache pour la durée de vie de l'actor) la config
    /// serveur Gigya/Kamereon à jour.
    private func serverConfig() async throws -> RenaultServerConfig {
        if let cached = cachedServerConfig { return cached }
        guard let url = URL(string: Self.configURL) else {
            throw RenaultServiceError.unknownError("URL de configuration invalide")
        }
        let request = URLRequest(url: url, timeoutInterval: 30)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw RenaultServiceError.unknownError("Impossible de récupérer la configuration serveur Renault")
        }
        let config = try JSONDecoder().decode(RenaultServerConfig.self, from: data)
        cachedServerConfig = config
        return config
    }

    // MARK: - Private: Full Auth Flow

    private func authenticate(email: String, password: String) async throws -> RenaultToken {
        let config = try await serverConfig()
        let gigyaToken = try await gigyaLogin(email: email, password: password, config: config.servers.gigyaProd)
        let gigyaJWT   = try await gigyaGetJWT(loginToken: gigyaToken, config: config.servers.gigyaProd)
        let token      = try await kamereonGetToken(gigyaJWT: gigyaJWT, config: config.servers.wiredProd)
        return token
    }

    // MARK: Step 1 — Gigya login → login_token

    private func gigyaLogin(email: String, password: String, config: RenaultServerConfig.Server) async throws -> String {
        let loginURL = config.target + "/accounts.login"
        var components = URLComponents(string: loginURL)!
        components.queryItems = [
            URLQueryItem(name: "loginID",  value: email),
            URLQueryItem(name: "password", value: password),
            URLQueryItem(name: "apiKey",   value: config.apikey),
            URLQueryItem(name: "format",   value: "json")
        ]
        let body = components.percentEncodedQuery?.data(using: .utf8)

        var request = URLRequest(url: URL(string: loginURL)!, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let data = try await performRequest(request)
        print("✅ Gigya Login Response: \(String(data: data, encoding: .utf8) ?? "N/A")")
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        print("📋 Gigya JSON: \(json ?? [:])")
        guard let statusCode = json?["statusCode"] as? Int, statusCode == 200,
              let loginToken = json?["sessionInfo"] as? [String: Any],
              let cookieValue = loginToken["cookieValue"] as? String
        else {
            let msg = (json?["errorMessage"] as? String) ?? "Échec login Gigya"
            print("❌ Gigya Error: \(msg)")
            throw RenaultServiceError.unknownError(msg)
        }
        return cookieValue
    }

    // MARK: Step 2 — Gigya getJWT → JWT

    private func gigyaGetJWT(loginToken: String, config: RenaultServerConfig.Server) async throws -> String {
        let jwtURL = config.target + "/accounts.getJWT"
        var components = URLComponents(string: jwtURL)!
        components.queryItems = [
            URLQueryItem(name: "login_token", value: loginToken),
            URLQueryItem(name: "apiKey",      value: config.apikey),
            URLQueryItem(name: "fields",      value: "data.personId,data.gigyaDataCenter"),
            URLQueryItem(name: "expiration",  value: "900"),
            URLQueryItem(name: "format",      value: "json")
        ]
        let body = components.percentEncodedQuery?.data(using: .utf8)

        var request = URLRequest(url: URL(string: jwtURL)!, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let data = try await performRequest(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let statusCode = json?["statusCode"] as? Int, statusCode == 200,
              let idToken = json?["id_token"] as? String
        else {
            let msg = (json?["errorMessage"] as? String) ?? "Échec getJWT Gigya"
            throw RenaultServiceError.unknownError(msg)
        }
        return idToken
    }

    // MARK: Step 3 — Kamereon token → accessToken + accountId

    private func kamereonGetToken(gigyaJWT: String, config: RenaultServerConfig.Server) async throws -> RenaultToken {
        let urlString = config.target + "/commerce/v1/persons/token"
        var request = URLRequest(url: URL(string: urlString)!, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(config.apikey,      forHTTPHeaderField: "x-api-key")
        request.setValue("RENAULT",          forHTTPHeaderField: "x-brand-id")
        request.setValue("fr_FR",            forHTTPHeaderField: "x-kamereon-locale")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["token": gigyaJWT])

        let data = try await performRequest(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let accessToken = json?["accessToken"] as? String else {
            throw RenaultServiceError.unknownError("Token Kamereon manquant")
        }
        // Durée de validité par défaut 15 min (900 s) sauf indication contraire
        let expiresIn = (json?["expiresIn"] as? Double) ?? 900
        let expiresAt = Date(timeIntervalSinceNow: expiresIn - 30) // marge 30 s

        // Stocker l'accountId si présent (nécessaire pour les appels suivants)
        if let accounts = json?["accounts"] as? [[String: Any]],
           let firstAccount = accounts.first,
           let accountId = firstAccount["accountId"] as? String {
            try? credentialStore.store(value: accountId, forKey: "renault_account_id")
        }

        return RenaultToken(accessToken: accessToken, expiresAt: expiresAt)
    }

    // MARK: - Helpers

    private func performRequest(_ request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw RenaultServiceError.unknownError("Réponse non HTTP")
            }
            switch http.statusCode {
            case 200...299: return data
            case 401:       throw RenaultServiceError.tokenExpired
            case 408:       throw RenaultServiceError.timeout
            default:        throw RenaultServiceError.unknownError("HTTP \(http.statusCode)")
            }
        } catch let err as RenaultServiceError {
            throw err
        } catch {
            throw RenaultServiceError.networkError(underlying: error)
        }
    }
}

// MARK: - RenaultToken

struct RenaultToken: Sendable {
    let accessToken: String
    let expiresAt: Date

    var isExpired: Bool {
        Date() >= expiresAt
    }
}

// MARK: - RenaultServerConfig

/// Config serveur Gigya/Kamereon récupérée dynamiquement, pour survivre
/// aux rotations de clé API côté Renault sans recompiler l'app.
struct RenaultServerConfig: Sendable, Decodable {
    struct Server: Sendable, Decodable {
        let target: String
        let apikey: String
    }
    struct Servers: Sendable, Decodable {
        let gigyaProd: Server
        let wiredProd: Server
    }
    let servers: Servers
}
