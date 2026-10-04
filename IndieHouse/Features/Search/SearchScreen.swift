import SwiftUI

struct SearchScreen: View {
    @EnvironmentObject private var model: AppModel
    @State private var query = ""
    @State private var results: SearchResult?
    @State private var resultsFor: String?
    @State private var searching = false
    @State private var error: String?
    @State private var filter = "all"
    @State private var pending: Task<Void, Never>?
    @State private var sequence = 0
    @State private var inFlight: String?
    @FocusState private var focused: Bool

    var body: some View {
        Page(title: Tab.search.title, root: .search) {
            PageTitle(text: Tab.search.title)
            field.padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 8)
            if query.trimmingCharacters(in: .whitespaces).isEmpty {
                start
            } else if let error, results == nil {
                EmptyState(icon: "alert", title: L("search.failed"), message: error, action: L("common.retry")) {
                    run(force: true)
                }
            } else if let results {
                resultsView(results)
            } else {
                SkeletonRows(count: 5)
            }
        }
        .onChange(of: model.refresh[Tab.search.rawValue]) { if !query.isEmpty { run(force: true) } }
    }

    private var field: some View {
        HStack(spacing: 10) {
            Icon("search", size: 20).foregroundStyle(Theme.muted)
            TextField("", text: $query, prompt: Text(L("search.placeholder")).foregroundStyle(Theme.faint))
                .font(.ih(.regular, 16))
                .tint(Theme.accent)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($focused)
                .accessibilityLabel(L("search.placeholder"))
                .onSubmit {
                    pending?.cancel()
                    let trimmed = query.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    model.rememberSearch(trimmed)
                    focused = false
                    run(force: true)
                }
                .onChange(of: query) { changed() }
            if !query.isEmpty {
                IconButton(icon: "close", label: L("search.clear_query"), glyph: 18, tint: Theme.muted) {
                    query = ""
                    focused = true
                }
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, query.isEmpty ? 14 : 4)
        .frame(height: 50)
        .background(Theme.field, in: Block())
        .overlay(Block().strokeBorder(focused ? Theme.accent : Theme.line))
    }

    private func changed() {
        if query.count > 120 { query = String(query.prefix(120)) }
        pending?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            results = nil
            resultsFor = nil
            searching = false
            error = nil
            return
        }
        // A chip or genre already started this search.
        if trimmed == inFlight || trimmed == resultsFor { return }
        pending = Task {
            try? await Task.sleep(for: .milliseconds(420))
            if !Task.isCancelled { run(force: false) }
        }
    }

    /// Only the newest request's results are shown.
    private func run(force: Bool) {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty, force || q != resultsFor || results == nil else { return }
        sequence += 1
        let mine = sequence
        searching = true
        inFlight = q
        error = nil
        Task {
            let result = await model.run { try await model.api.search(q) }
            guard mine == sequence else { return }
            searching = false
            inFlight = nil
            switch result {
            case let .success(found):
                results = found
                resultsFor = q
                filter = "all"
                model.remember(found.tracks)
            case let .failure(failure):
                guard !model.isCancellation(failure) else { return }
                if results == nil { error = model.message(for: failure) }
                else { model.show(model.message(for: failure), error: true) }
            }
        }
    }

    private func search(_ text: String) {
        pending?.cancel()
        query = text
        results = nil
        resultsFor = nil
        model.rememberSearch(text)
        focused = false
        run(force: true)
    }

    @ViewBuilder
    private var start: some View {
        let recent = model.recentSearches
        if !recent.isEmpty {
            SectionHeading(title: L("search.recent"), action: L("common.clear")) { model.clearRecentSearches() }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(recent, id: \.self) { text in Chip(title: text) { search(text) } }
                }
                .padding(.horizontal, 16)
            }
        }
        let genres = model.knownGenres()
        if genres.isEmpty {
            EmptyState(icon: "search", title: L("search.start_title"), message: L("search.start_body"))
        } else {
            SectionHeading(title: L("search.genres"))
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(genres, id: \.name) { genre in
                    GenreTile(name: genre.name, count: genre.count) { search(genre.name) }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func resultsView(_ data: SearchResult) -> some View {
        let q = resultsFor ?? query.trimmingCharacters(in: .whitespaces)
        if data.tracks.isEmpty && data.artists.isEmpty && data.albums.isEmpty {
            EmptyState(icon: "search", title: L("search.no_results_title", q), message: L("search.no_results_body"),
                       action: Tab.browse.title) { model.switchTo(.browse) }
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Chip(title: L("search.filter.all"), active: filter == "all") { filter = "all" }
                    if !data.tracks.isEmpty {
                        Chip(title: "\(L("search.filter.songs"))  \(data.tracks.count)", active: filter == "tracks") { filter = "tracks" }
                    }
                    if !data.artists.isEmpty {
                        Chip(title: "\(L("search.filter.artists"))  \(data.artists.count)", active: filter == "artists") { filter = "artists" }
                    }
                    if !data.albums.isEmpty {
                        Chip(title: "\(L("search.filter.albums"))  \(data.albums.count)", active: filter == "albums") { filter = "albums" }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 4)
            let context = "search:\(q)"
            let label = L("search.context", q)
            switch filter {
            case "tracks":
                TrackList(tracks: data.tracks, context: context, label: label).padding(.top, 8)
            case "artists":
                VStack(spacing: 0) {
                    ForEach(data.artists) { artist in
                        MediaRow(title: artist.name, subtitle: L("kind.artist"), seed: artist.name,
                                 artwork: artist.artworkUrl ?? artist.avatarUrl, octagon: true) {
                            model.push(.artist(id: artist.id, name: artist.name))
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)
            case "albums":
                VStack(spacing: 0) {
                    ForEach(data.albums) { album in
                        MediaRow(title: album.title, subtitle: album.artistName, seed: album.title, artwork: album.artworkUrl) {
                            model.push(.album(id: album.id, title: album.title))
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)
            default:
                TopResult(query: q, data: data)
                if !data.tracks.isEmpty {
                    SectionHeading(title: L("search.filter.songs"),
                                   action: data.tracks.count > 4 ? L("common.see_all") : nil) { filter = "tracks" }
                    TrackList(tracks: Array(data.tracks.prefix(4)), queue: data.tracks, context: context, label: label)
                }
                if !data.artists.isEmpty {
                    SectionHeading(title: L("search.filter.artists"))
                    ArtistShelf(artists: data.artists)
                }
                if !data.albums.isEmpty {
                    SectionHeading(title: L("search.filter.albums"))
                    AlbumShelf(albums: data.albums)
                }
            }
        }
    }
}
