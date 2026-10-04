import Foundation

struct Envelope<T: Decodable>: Decodable { let data: T }

/// An artist: a reference inside track data, a search result, a list entry
/// (with its song count) or the artist page (with bio and tracks).
struct Artist: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    var avatarUrl: URL? = nil
    var artworkUrl: URL? = nil
    var bio: String? = nil
    var tracks: [Track]? = nil
    var trackCount: Int? = nil

    static func == (lhs: Artist, rhs: Artist) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// An album: a reference inside track data, a search result, a list entry or the album page.
struct Album: Decodable, Identifiable, Hashable {
    let id: String
    let title: String
    var artist: Artist? = nil
    var artworkUrl: URL? = nil
    var description: String? = nil
    var tracks: [Track]? = nil
    var trackCount: Int? = nil

    var artistName: String { artist?.name ?? L("artist.unknown") }
    static func == (lhs: Album, rhs: Album) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct Track: Decodable, Identifiable, Hashable {
    let id: String
    let title: String
    let durationSeconds: Int?
    let genre: String?
    let artist: Artist?
    let albums: [Album]?
    let artworkUrl: URL?
    let streamPath: String?

    var displayTitle: String { title.isEmpty ? L("common.untitled") : title }
    var artistName: String { artist?.name ?? L("artist.unknown") }
    var firstAlbum: Album? { albums?.first }
    var genreName: String? {
        guard let genre = genre?.trimmingCharacters(in: .whitespaces), !genre.isEmpty else { return nil }
        return genre
    }
    static func == (lhs: Track, rhs: Track) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct SearchResult: Decodable { let tracks: [Track]; let artists: [Artist]; let albums: [Album] }

struct Playlist: Decodable, Identifiable, Hashable {
    let id: String
    var title: String
    var description: String?
    var isPublic: Bool?
    var tracksCount: Int?
    var tracks: [Track]?

    var seed: String { "playlist:\(id)" }
    static func == (lhs: Playlist, rhs: Playlist) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct PlayHistory: Decodable { let track: Track; let createdAt: String? }

struct LibraryData: Decodable {
    var playlists: [Playlist]
    var history: [PlayHistory]

    /// Recently played songs, once each, newest first.
    var recentTracks: [Track] {
        var seen = Set<String>()
        return history.map(\.track).filter { seen.insert($0.id).inserted }
    }
}

/// One page of `GET catalogue`, most played first.
struct CataloguePage: Decodable {
    struct Meta: Decodable { let currentPage: Int; let lastPage: Int; let total: Int }
    let data: [Track]
    let meta: Meta?
}

/// `GET browse`: the newest songs and albums and the most played artists.
struct BrowseData: Decodable {
    struct Counts: Decodable { let tracks: Int; let albums: Int; let artists: Int }
    let counts: Counts
    let newTracks: [Track]
    let albums: [Album]
    let artists: [Artist]
}

/// One page of `GET albums` (newest first) or `GET artists` (A to Z).
struct ListPage<Item: Decodable>: Decodable {
    let data: [Item]
    let meta: CataloguePage.Meta?
}
