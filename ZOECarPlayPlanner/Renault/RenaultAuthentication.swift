import Foundation

// MARK: - RenaultAuthentication

/// Gestion de l'authentification Renault/MyRenault.
/// L'implémentation réelle utilise Keychain via SecureStorage.
///
/// TODO: Implémenter l'authentification OAuth2 Renault
///       en se basant sur la référence open-source :
///       https://github.com/hacf-fr/renault-api
actor RenaultAuthentication {
    private let credentialStore: CredentialStore
    private var cachedToken: RenaultToken?

    init(credentialStore: CredentialStore = KeychainCredentialStore()) {
        self.credentialStore = credentialStore
    }

    // MARK: - Token

    /// Retourne un token valide, ou lève une erreur.
    func validToken() async throws -> RenaultToken {
        if let token = cachedToken, !token.isExpired {
            return token
        }
        // TODO: Implémenter le rafraîchissement du token
        throw RenaultServiceError.notAuthenticated
    }

    func storeCredentials(email: String, password: String) async throws {
        // Les credentials sont stockés dans Keychain, jamais en clair dans le code.
        try credentialStore.store(value: email, forKey: "renault_email")
        try credentialStore.store(value: password, forKey: "renault_password")
    }

    func clearCredentials() {
        try? credentialStore.delete(forKey: "renault_email")
        try? credentialStore.delete(forKey: "renault_password")
        cachedToken = nil
    }

    var hasCredentials: Bool {
        (try? credentialStore.retrieve(forKey: "renault_email")) != nil
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
