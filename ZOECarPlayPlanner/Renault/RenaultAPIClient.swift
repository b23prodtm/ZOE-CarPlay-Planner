import Foundation

// MARK: - RenaultAPIClient

/// Client HTTP bas-niveau pour l'API privée Renault/MyRenault.
///
/// Référence : https://github.com/hacf-fr/renault-api
///
/// IMPORTANT : Ne jamais stocker de credentials dans ce fichier.
/// Tous les accès passent par RenaultAuthentication + SecureStorage.
actor RenaultAPIClient {
    private let session: URLSession
    private let auth: RenaultAuthentication

    // Endpoints Renault (privés, non officiels — susceptibles de changer)
    private enum Endpoint {
        static let kamereonBase = "https://api-wired-prod-1-euw1.wrd-aws.com/commerce/v1"
        static let gigya = "https://accounts.eu1.gigya.com"
    }

    init(auth: RenaultAuthentication, session: URLSession = .shared) {
        self.auth = auth
        self.session = session
    }

    // MARK: - Requêtes

    /// Effectue une requête authentifiée vers l'API Kamereon.
    func get(path: String) async throws -> Data {
        let token = try await auth.validToken()
        guard let url = URL(string: Endpoint.kamereonBase + path) else {
            throw RenaultServiceError.unknownError("URL invalide : \(path)")
        }
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.setValue("******", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw RenaultServiceError.unknownError("Réponse non HTTP")
            }
            switch http.statusCode {
            case 200...299:
                return data
            case 401:
                throw RenaultServiceError.tokenExpired
            case 408:
                throw RenaultServiceError.timeout
            default:
                throw RenaultServiceError.unknownError("HTTP \(http.statusCode)")
            }
        } catch let error as RenaultServiceError {
            throw error
        } catch {
            throw RenaultServiceError.networkError(underlying: error)
        }
    }
}
