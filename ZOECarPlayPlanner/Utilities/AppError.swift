import Foundation

// MARK: - AppError

/// Erreur générique affichable à l'utilisateur.
struct AppError: LocalizedError, Sendable {
    let message: String
    var errorDescription: String? { message }

    static func from(_ error: Error) -> AppError {
        AppError(message: error.localizedDescription)
    }
}
