import SwiftUI

enum Tab: Int, CaseIterable, Identifiable {
    case home, search, browse, library

    var id: Int { rawValue }
    var title: String { L("tab.\(key)") }
    var icon: String { ["home", "search", "compass", "library"][rawValue] }
    private var key: String { ["home", "search", "browse", "library"][rawValue] }
}

/// A page pushed on a tab's stack.
enum Route: Hashable {
    case album(id: String, title: String)
    case artist(id: String, name: String)
    case playlist(id: String, title: String)
    case history
    /// Every album, newest first.
    case albums
    /// Every artist, A to Z.
    case artists
    case settings
    /// "terms" or "privacy".
    case legal(document: String)
}

struct ToastItem: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let error: Bool
}

struct ConfirmRequest: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let action: String
    var destructive = true
    let perform: () -> Void
}

enum SheetKind: Identifiable {
    case trackMenu(Track, playlistId: String?)
    case addToPlaylist(Track, [Playlist])
    case playlistForm(editing: Playlist?, track: Track?)
    case queue

    var id: String {
        switch self {
        case let .trackMenu(track, playlist): "menu.\(track.id).\(playlist ?? "")"
        case let .addToPlaylist(track, _): "add.\(track.id)"
        case let .playlistForm(editing, track): "form.\(editing?.id ?? "").\(track?.id ?? "")"
        case .queue: "queue"
        }
    }
}

enum Stage: Equatable {
    case starting
    case failed(String)
    case auth
    case app
}

struct HomeData {
    var catalogue: [Track]
    var library: LibraryData
    /// The newest albums.
    var albums: [Album]
}
