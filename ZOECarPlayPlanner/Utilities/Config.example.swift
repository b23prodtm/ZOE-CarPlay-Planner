import Foundation

// MARK: - Config.example.swift
//
// Copiez ce fichier en Config.swift et remplissez les valeurs locales.
// Ne JAMAIS committer Config.swift dans le dépôt Git.
//
// Config.swift est déjà dans .gitignore.

struct AppConfig {
    // MARK: - Google Maps (optionnel)
    /// Clé API Google Maps/Routes. Laisser vide si non utilisé.
    static let googleMapsAPIKey: String = ""

    // MARK: - Renault API (optionnel)
    /// VIN (numéro de châssis) du véhicule réel.
    /// Laisser vide pour utiliser le mode simulation.
    static let vehicleVIN: String = ""

    // MARK: - Renault compte (optionnel)
    /// Email du compte MyRenault.
    /// Ne JAMAIS mettre le mot de passe ici.
    /// Utiliser SecureStorage / KeychainCredentialStore.
    static let renaultAccountEmail: String = ""
}
