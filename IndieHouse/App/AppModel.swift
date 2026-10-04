import SwiftUI

/// App state shared by every screen: navigation, toasts, sheets, dialogs and
/// the actions behind menus. The API client and the player live here, so
/// switching language (which rebuilds the views) does not stop the music.
@MainActor final class AppModel: ObservableObject {
    let api = IndieAPI()
    let player = MusicPlayer()

    @Published var stage: Stage = .starting
    /// Shown on the sign-in screen, e.g. after the session expired.
    @Published var notice: String?
    @Published var tab: Tab = .home
    @Published var paths: [[Route]] = Array(repeating: [], count: Tab.allCases.count)
    @Published private(set) var loading = 0
    @Published private(set) var toast: ToastItem?
    @Published var sheet: SheetKind?
    @Published var confirm: ConfirmRequest?
    @Published var playerOpen = false
    @Published var home: HomeData?
    @Published var preferences = ListeningPreferences.default
    /// Name, email and picture; nil until loaded, or on a server without `/account`.
    @Published var account: AccountProfile?
    /// Bumped whenever playlists or history change; pages built on them refresh.
    @Published private(set) var libraryVersion = 0
    @Published private(set) var scrollToTop = Array(repeating: 0, count: Tab.allCases.count)
    @Published private(set) var refresh = Array(repeating: 0, count: Tab.allCases.count)

    /// Whether each tab's first page is scrolled to the top; not published, it changes on every scroll.
    var atTop = Array(repeating: true, count: Tab.allCases.count)
    private var known: [String: Track] = [:]
    private var knownOrder: [String] = []

    init() {
        player.onError = { [weak self] message in self?.show(message, error: true) }
    }

    // MARK: Requests

    /// Runs a request with the loading strip. A rejected session is handled by the shell.
    func run<T>(_ work: () async throws -> T) async -> Result<T, Error> {
        loading += 1
        defer { loading -= 1 }
        do { return .success(try await work()) } catch { return .failure(error) }
    }

    /// Runs an action and reports a failure as a toast.
    @discardableResult
    func attempt<T>(_ work: () async throws -> T) async -> T? {
        switch await run(work) {
        case let .success(value): return value
        case let .failure(error):
            if !isCancellation(error) && api.signedIn { show(message(for: error), error: true) }
            return nil
        }
    }

    func message(for error: Error) -> String {
        if let url = error as? URLError {
            switch url.code {
            case .secureConnectionFailed, .serverCertificateUntrusted, .serverCertificateHasBadDate,
                 .serverCertificateNotYetValid, .serverCertificateHasUnknownRoot, .clientCertificateRejected:
                return L("error.tls")
            case .notConnectedToInternet, .cannotFindHost, .cannotConnectToHost, .timedOut,
                 .networkConnectionLost, .dnsLookupFailed, .internationalRoamingOff, .dataNotAllowed:
                return L("error.network")
            default:
                return L("error.generic")
            }
        }
        let text = error.localizedDescription
        return text.isEmpty ? L("error.generic") : text
    }

    func isCancellation(_ error: Error) -> Bool {
        error is CancellationError || (error as? URLError)?.code == .cancelled
    }

    func show(_ message: String, error: Bool = false) {
        let item = ToastItem(message: message, error: error)
        withAnimation(.toast) { toast = item }
        Task {
            try? await Task.sleep(for: .seconds(error ? 4.2 : 2.6))
            if toast == item { withAnimation(.toast) { toast = nil } }
        }
    }

    // MARK: Navigation

    func push(_ route: Route) {
        playerOpen = false
        sheet = nil
        paths[tab.rawValue].append(route)
    }

    /// Tapping the active tab returns to its first page, then to the top, then refreshes.
    func select(_ target: Tab) {
        guard target == tab else {
            tab = target
            return
        }
        let index = target.rawValue
        if !paths[index].isEmpty {
            paths[index] = []
        } else if !atTop[index] {
            scrollToTop[index] += 1
        } else {
            refresh[index] += 1
        }
    }

    func switchTo(_ target: Tab) {
        tab = target
        paths[target.rawValue] = []
    }

    // MARK: Session

    /// Home data: the first catalogue page, the library and the newest albums. Also proves the session works.
    func loadHome() async throws -> HomeData {
        async let catalogue = api.catalogue(page: 1)
        async let library: LibraryData = api.get("library")
        async let newest: ListPage<Album> = api.list("albums", page: 1)
        let page = try await catalogue
        // Servers before `GET albums` get the albums of the most played songs, as before.
        let albums = (try? await newest)?.data ?? AppModel.albums(of: page.data)
        let data = HomeData(catalogue: page.data, library: try await library, albums: Array(albums.prefix(12)))
        remember(data.catalogue)
        remember(data.library.recentTracks)
        home = data
        return data
    }

    func enterApp() {
        tab = .home
        paths = Array(repeating: [], count: Tab.allCases.count)
        Task { await syncPreferences() }
        Task { await syncAccount() }
    }

    func leaveApp() {
        player.stop()
        playerOpen = false
        sheet = nil
        home = nil
        account = nil
        known = [:]
        knownOrder = []
    }

    func syncPreferences() async {
        guard let saved: ListeningPreferences = try? await api.get("preferences") else { return }
        apply(saved)
    }

    func syncAccount() async {
        guard let latest: AccountProfile = try? await api.get("account") else { return }
        account = latest
    }

    private func apply(_ saved: ListeningPreferences) {
        preferences = saved
        player.quality = saved.audioQuality
        player.autoplay = saved.autoplay
        player.recordHistory = saved.recordListeningHistory
    }

    /// The page shows the new value at once and reverts if saving fails.
    func savePreferences(_ updated: ListeningPreferences, key: String, value: Any) async {
        let previous = preferences
        preferences = updated
        let result = await run { try await api.send("PATCH", "preferences", body: [key: value], as: ListeningPreferences.self) }
        switch result {
        case let .success(saved):
            apply(saved)
            show(L("common.saved"))
        case let .failure(error):
            preferences = previous
            if api.signedIn { show(message(for: error), error: true) }
        }
    }

    func signOut() {
        confirm = ConfirmRequest(title: L("account.logout_title"), message: L("account.logout_body"),
                                 action: L("account.logout")) { [weak self] in
            guard let self else { return }
            leaveApp()
            Task { await self.api.logout() }
        }
    }

    func changeLibrary() {
        confirm = ConfirmRequest(title: L("library.change_title"),
                                 message: L("library.change_body", api.profile?.name ?? ""),
                                 action: L("library.change")) { [weak self] in
            guard let self else { return }
            leaveApp()
            Task { await self.api.disconnect() }
        }
    }

    // MARK: Playback

    func play(_ tracks: [Track], at index: Int, context: String?, label: String?, shuffled: Bool = false) {
        player.start(tracks, at: index, context: context, label: label, shuffled: shuffled, using: api)
    }

    /// A page's play button pauses or resumes its own list and starts it otherwise.
    func playContext(_ tracks: [Track], context: String, label: String) {
        if player.current != nil && player.contextId == context { player.toggle() }
        else { play(tracks, at: 0, context: context, label: label, shuffled: player.shuffle) }
    }

    func isPlaying(context: String) -> Bool {
        player.current != nil && player.contextId == context && (player.isPlaying || player.isLoading)
    }

    // MARK: Library actions

    func libraryChanged() { libraryVersion += 1 }

    func trackMenu(_ track: Track, playlistId: String? = nil) {
        sheet = .trackMenu(track, playlistId: playlistId)
    }

    func playNext(_ track: Track) {
        player.playNext(track, using: api)
        show(L("menu.will_play_next", track.displayTitle))
    }

    func addToPlaylist(_ track: Track) {
        sheet = nil
        Task {
            guard let playlists: [Playlist] = await attempt({ try await api.get("playlists") }) else { return }
            sheet = .addToPlaylist(track, playlists)
        }
    }

    func add(_ track: Track, to playlist: Playlist) async {
        guard await attempt({ try await api.post("playlists/\(playlist.id)/tracks", body: ["track_id": track.id]) }) != nil
        else { return }
        libraryChanged()
        show(L("playlist.added", playlist.title))
    }

    func remove(_ track: Track, from playlistId: String) async {
        guard await attempt({ try await api.delete("playlists/\(playlistId)/tracks/\(track.id)") }) != nil else { return }
        libraryChanged()
        show(L("playlist.removed"))
    }

    /// Creates or edits a playlist; a new one made from a song's menu gets that song.
    func savePlaylist(editing: Playlist?, track: Track?, title: String, description: String,
                      isPublic: Bool) async throws {
        let body: [String: Any] = ["title": title, "is_public": isPublic,
                                   "description": description.isEmpty ? NSNull() : description]
        let result = await run {
            if let editing {
                try await api.send("PATCH", "playlists/\(editing.id)", body: body, as: Playlist.self)
            } else {
                try await api.send("POST", "playlists", body: body, as: Playlist.self)
            }
        }
        let saved = try result.get()
        sheet = nil
        libraryChanged()
        if editing != nil {
            show(L("playlist.saved"))
        } else if let track {
            await add(track, to: saved)
        } else {
            show(L("playlist.created", saved.title))
        }
    }

    func deletePlaylist(_ playlist: Playlist) {
        confirm = ConfirmRequest(title: L("playlist.delete_title"), message: L("playlist.delete_body", playlist.title),
                                 action: L("playlist.delete")) { [weak self] in
            guard let self else { return }
            Task {
                guard await self.attempt({ try await self.api.delete("playlists/\(playlist.id)") }) != nil else { return }
                for index in self.paths.indices {
                    self.paths[index].removeAll {
                        if case let .playlist(id, _) = $0 { return id == playlist.id }
                        return false
                    }
                }
                self.libraryChanged()
                self.show(L("playlist.deleted"))
            }
        }
    }

    // MARK: Session memory

    /// Songs seen this session (at most 600), used for the genre grid.
    func remember(_ tracks: [Track]) {
        for track in tracks {
            if known.updateValue(track, forKey: track.id) == nil { knownOrder.append(track.id) }
        }
        while knownOrder.count > 600 { known[knownOrder.removeFirst()] = nil }
    }

    /// At most 12 genres of songs seen this session, most common first.
    func knownGenres() -> [(name: String, count: Int)] {
        var counts: [String: Int] = [:]
        var labels: [String: String] = [:]
        for id in knownOrder {
            guard let genre = known[id]?.genreName else { continue }
            let key = genre.lowercased()
            counts[key, default: 0] += 1
            if labels[key] == nil { labels[key] = genre }
        }
        let genres: [(name: String, count: Int)] = counts.map { key, count in (name: labels[key] ?? key, count: count) }
        let sorted = genres.sorted { left, right in
            if left.count != right.count { return left.count > right.count }
            return left.name.localizedCaseInsensitiveCompare(right.name) == .orderedAscending
        }
        return Array(sorted.prefix(12))
    }

    var recentSearches: [String] {
        get { UserDefaults.standard.stringArray(forKey: "recent_searches") ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: "recent_searches") }
    }

    /// Newest first, at most 8, duplicates compared without case.
    func rememberSearch(_ query: String) {
        let rest = recentSearches.filter { $0.caseInsensitiveCompare(query) != .orderedSame }
        recentSearches = Array(([query] + rest).prefix(8))
        objectWillChange.send()
    }

    func clearRecentSearches() {
        recentSearches = []
        objectWillChange.send()
    }

    /// Albums and artists (at most 12 each) built from song data, for shelves.
    static func albums(of tracks: [Track]) -> [Album] {
        var seen = Set<String>()
        var result: [Album] = []
        for track in tracks {
            for album in track.albums ?? [] where seen.insert(album.id).inserted {
                result.append(Album(id: album.id, title: album.title, artist: track.artist))
            }
        }
        return Array(result.prefix(12))
    }

    static func artists(of tracks: [Track]) -> [Artist] {
        var seen = Set<String>()
        return Array(tracks.compactMap(\.artist).filter { seen.insert($0.id).inserted }.prefix(12))
    }
}
