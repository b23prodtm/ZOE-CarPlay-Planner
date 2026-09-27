import Foundation

// MARK: - RenaultAPIClient
//
// Client HTTP pour l'API privée Renault/Kamereon.
// Référence : https://github.com/hacf-fr/renault-api
//
// IMPORTANT : Ne jamais stocker de credentials dans ce fichier.
// Tous les accès passent par RenaultAuthentication + SecureStorage (Keychain).
//
// L'endpoint et la clé API Kamereon sont récupérés dynamiquement via
// auth.kamereonServerInfo() plutôt que codés en dur, pour survivre aux
// rotations de clé côté Renault sans recompiler l'app.

actor RenaultAPIClient {
    private let session: URLSession
    private let auth: RenaultAuthentication
    private let credentialStore: CredentialStore

    init(auth: RenaultAuthentication,
         credentialStore: CredentialStore = KeychainCredentialStore(),
         session: URLSession = .shared) {
        self.auth = auth
        self.credentialStore = credentialStore
        self.session = session
    }

    // MARK: - Public API

    /// GET authentifié vers l'API Kamereon, avec un retry automatique
    /// en cas d'échec d'auth (401/403) — voir performWithRetry.
    func get(path: String) async throws -> Data {
        try await performWithRetry {
            let request = try await self.buildRequest(method: "GET", path: path, body: nil)
            return try await self.perform(request)
        }
    }

    /// POST authentifié vers l'API Kamereon, avec un retry automatique
    /// en cas d'échec d'auth (401/403) — voir performWithRetry.
    func post(path: String, body: [String: Any]) async throws -> Data {
        try await performWithRetry {
            let bodyData = try JSONSerialization.data(withJSONObject: body)
            let request  = try await self.buildRequest(method: "POST", path: path, body: bodyData)
            return try await self.perform(request)
        }
    }

    // MARK: - accountId helper

    /// Retourne l'accountId stocké après authentification.
    func accountId() throws -> String {
        try credentialStore.retrieve(forKey: "renault_account_id")
    }

    // MARK: - Retry wrapper

    /// Exécute `operation` ; si elle échoue avec une erreur d'auth (401/403),
    /// invalide la session (token + clé API) et retente UNE fois seulement.
    /// Pas de retry en boucle : un deuxième échec signifie que le problème
    /// n'est pas une clé/token périmé (ex. credentials invalides, TFA) —
    /// dans ce cas l'erreur remonte telle quelle à l'appelant.
    private func performWithRetry(_ operation: () async throws -> Data) async throws -> Data {
        do {
            return try await operation()
        } catch RenaultServiceError.tokenExpired, RenaultServiceError.unauthorized {
            await auth.invalidateSession()
            return try await operation()
        }
    }

    // MARK: - Private helpers

    private func buildRequest(method: String, path: String, body: Data?) async throws -> URLRequest {
        let token = try await auth.validToken()
        let serverInfo = try await auth.kamereonServerInfo()
        guard let url = URL(string: serverInfo.base + path) else {
            throw RenaultServiceError.unknownError("URL invalide : \(path)")
        }
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = method
        request.httpBody   = body
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json",            forHTTPHeaderField: "Accept")
        request.setValue("application/json",            forHTTPHeaderField: "Content-Type")
        request.setValue(serverInfo.apiKey,              forHTTPHeaderField: "x-api-key")
        request.setValue("RENAULT",                      forHTTPHeaderField: "x-brand-id")
        request.setValue("fr_FR",                         forHTTPHeaderField: "x-kamereon-locale")
        return request
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw RenaultServiceError.unknownError("Réponse non HTTP")
            }
            switch http.statusCode {
            case 200...299: return data
            case 401:       throw RenaultServiceError.tokenExpired
            case 403:       throw RenaultServiceError.unauthorized
            case 408:       throw RenaultServiceError.timeout
            case 503:       throw RenaultServiceError.apiUnavailable
            default:        throw RenaultServiceError.unknownError("HTTP \(http.statusCode)")
            }
        } catch let err as RenaultServiceError {
            throw err
        } catch {
            throw RenaultServiceError.networkError(underlying: error)
        }
    }
}
