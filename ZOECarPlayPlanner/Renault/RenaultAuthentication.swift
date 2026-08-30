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
// Les credentials (email, password) ne sont stockés que dans le Keychain.
// Les tokens sont conservés en mémoire uniquement et jamais persistés.

actor RenaultAuthentication {
    private let credentialStore: CredentialStore
    private let session: URLSession
    private var cachedToken: RenaultToken?

    // MARK: - Gigya / Kamereon endpoints (privés, non officiels)
    // Source : hacf-fr/renault-api  renault/const.py
    private enum GigyaEndpoint {
        static let apiKey = "3_e8d4g4SE_Fo8ahyHwwP21pqT2Z6L18MWbCK1DgDcXZ8cbOKe5n" // clé publique Gigya Renault EU
        static let login  = "https://accounts.eu1.gigya.com/accounts.login"
        static let jwt    = "https://accounts.eu1.gigya.com/accounts.getJWT"
    }
    private enum KamereonEndpoint {
        static let base  = "https://api-wired-prod-1-euw1.wrd-aws.com/commerce/v1"
        static let token = "/persons/token"
        // Clé API publique Kamereon Renault EU (header x-api-key)
        static let apiKey = "oF09WnKqvBDcrQzcW1rJ70D1nsB_AZkbTIKSxE_8JA8w"
        static let brand  = "RENAULT"
        static let locale = "fr_FR"
    }

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

    // MARK: - Private: Full Auth Flow

    private func authenticate(email: String, password: String) async throws -> RenaultToken {
        let gigyaToken = try await gigyaLogin(email: email, password: password)
        let gigyaJWT   = try await gigyaGetJWT(loginToken: gigyaToken)
        let token      = try await kamereonGetToken(gigyaJWT: gigyaJWT)
        return token
    }

    // MARK: Step 1 — Gigya login → login_token

    private func gigyaLogin(email: String, password: String) async throws -> String {
        var components = URLComponents(string: GigyaEndpoint.login)!
        components.queryItems = [
            URLQueryItem(name: "loginID",  value: email),
            URLQueryItem(name: "password", value: password),
            URLQueryItem(name: "apiKey",   value: GigyaEndpoint.apiKey),
            URLQueryItem(name: "format",   value: "json")
        ]
        let body = components.percentEncodedQuery?.data(using: .utf8)

        var request = URLRequest(url: URL(string: GigyaEndpoint.login)!, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let data = try await performRequest(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let statusCode = json?["statusCode"] as? Int, statusCode == 200,
              let loginToken = json?["sessionInfo"] as? [String: Any],
              let cookieValue = loginToken["cookieValue"] as? String
        else {
            let msg = (json?["errorMessage"] as? String) ?? "Échec login Gigya"
            throw RenaultServiceError.unknownError(msg)
        }
        return cookieValue
    }

    // MARK: Step 2 — Gigya getJWT → JWT

    private func gigyaGetJWT(loginToken: String) async throws -> String {
        var components = URLComponents(string: GigyaEndpoint.jwt)!
        components.queryItems = [
            URLQueryItem(name: "login_token", value: loginToken),
            URLQueryItem(name: "apiKey",      value: GigyaEndpoint.apiKey),
            URLQueryItem(name: "fields",      value: "data.personId,data.gigyaDataCenter"),
            URLQueryItem(name: "expiration",  value: "900"),
            URLQueryItem(name: "format",      value: "json")
        ]
        let body = components.percentEncodedQuery?.data(using: .utf8)

        var request = URLRequest(url: URL(string: GigyaEndpoint.jwt)!, timeoutInterval: 30)
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

    private func kamereonGetToken(gigyaJWT: String) async throws -> RenaultToken {
        let urlString = KamereonEndpoint.base + KamereonEndpoint.token
        var request = URLRequest(url: URL(string: urlString)!, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/json",         forHTTPHeaderField: "Content-Type")
        request.setValue("application/json",         forHTTPHeaderField: "Accept")
        request.setValue(KamereonEndpoint.apiKey,    forHTTPHeaderField: "x-api-key")
        request.setValue(KamereonEndpoint.brand,     forHTTPHeaderField: "x-brand-id")
        request.setValue(KamereonEndpoint.locale,    forHTTPHeaderField: "x-kamereon-locale")
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
