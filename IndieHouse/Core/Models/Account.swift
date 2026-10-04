import Foundation

struct MobileDevice: Decodable, Identifiable {
    let id: String
    let deviceName: String?
    let platform: String?
    let lastUsedAt: String?
}

struct ListeningPreferences: Codable, Equatable {
    var audioQuality: String
    var autoplay: Bool
    var recordListeningHistory: Bool
    /// Set when an admin granted lossless; older servers omit it.
    var losslessAvailable: Bool? = nil
    static let `default` = ListeningPreferences(audioQuality: "auto", autoplay: true, recordListeningHistory: true)
}
struct Tokens: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
}
struct TokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
}

/// The signed-in user, from `GET /account`.
struct AccountProfile: Decodable, Equatable {
    let name: String
    let email: String
    /// A mobile API address loaded with the Bearer token, like artwork. It changes with the picture.
    let avatarUrl: URL?
}

/// The terms of use or privacy policy from `GET /legal/{document}`, in the app's language.
struct LegalDocument: Decodable {
    struct Section: Decodable {
        let title: String
        let paragraphs: [String]
        let items: [Item]
    }

    /// A list item; privacy items name what they describe, e.g. "Account".
    struct Item: Decodable {
        let label: String?
        let text: String
    }

    struct Contact: Decodable {
        let title: String
        /// With an email, the text ends where the address goes.
        let text: String
        let email: String?
    }

    let title: String
    let updated: String
    let intro: String
    let sections: [Section]
    let contact: Contact
}
