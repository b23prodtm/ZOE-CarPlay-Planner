import Foundation

// MARK: - RenaultAPIClient
//
// Client HTTP pour l'API privée Renault/Kamereon.
// Référence : https://github.com/hacf-fr/renault-api
//
// IMPORTANT : Ne jamais stocker de credentials dans ce fichier.
// Tous les accès passent par RenaultAuthentication + SecureStorage (Keychain).

actor RenaultAPIClient {
    private let session: URLSession
    private let auth: RenaultAuthentication
    private let credentialStore: CredentialStore

    // MARK: - Endpoints (privés, non officiels — susceptibles de changer)
    enum Endpoint {
        static let kamereonBase = "https://api-wired-prod-1-euw1.wrd-aws.com/commerce/v1"
        static let kamereonAPIKey = "oF09WnKqvBDcrQzcW1rJ70D1nsB_AZkbTIKSxE_8JA8w"
        static let brand  = "RENAULT"
        static let locale = "fr_FR"
    }

    init(auth: RenaultAuthentication,
         credentialStore: CredentialStore = KeychainCredentialStore(),
         session: URLSession = .shared) {
        self.auth = auth
        self.credentialStore = credentialStore
        self.session = session
    }

    // MARK: - Public API

    /// GET authentifié vers l'API Kamereon.
    func get(path: String) async throws -> Data {
        let request = try await buildRequest(method: "GET", path: path, body: nil)
        return try await perform(request)
    }

    /// POST authentifié vers l'API Kamereon.
    func post(path: String, body: [String: Any]) async throws -> Data {
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let request  = try await buildRequest(method: "POST", path: path, body: bodyData)
        return try await perform(request)
    }

    // MARK: - accountId helper

    /// Retourne l'accountId stocké après authentification.
    func accountId() throws -> String {
        try credentialStore.retrieve(forKey: "renault_account_id")
    }

    // MARK: - Private helpers

    private func buildRequest(method: String, path: String, body: Data?) async throws -> URLRequest {
        let token = try await auth.validToken()
        guard let url = URL(string: Endpoint.kamereonBase + path) else {
            throw RenaultServiceError.unknownError("URL invalide : \(path)")
        }
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = method
        request.httpBody   = body
        request.setValue("******", forHTTPHeaderField: "Authorization")
        request.setValue("application/json",            forHTTPHeaderField: "Accept")
        request.setValue("application/json",            forHTTPHeaderField: "Content-Type")
        request.setValue(Endpoint.kamereonAPIKey,       forHTTPHeaderField: "x-api-key")
        request.setValue(Endpoint.brand,                forHTTPHeaderField: "x-brand-id")
        request.setValue(Endpoint.locale,               forHTTPHeaderField: "x-kamereon-locale")
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
