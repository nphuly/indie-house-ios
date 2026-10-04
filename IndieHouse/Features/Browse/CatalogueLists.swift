import SwiftUI

/// Every album, newest first, in two columns: "Xem tất cả" from the album shelves.
struct AlbumsScreen: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var api: IndieAPI
    @StateObject private var list = PagedLoader<Album>(path: "albums")
    private let columns = [GridItem(.flexible(), spacing: 12, alignment: .top), GridItem(.flexible(), spacing: 12, alignment: .top)]

    var body: some View {
        Page(title: L("browse.albums"), refresh: { await list.reload(model) }) {
            if list.loaded {
                PageTitle(text: L("browse.albums"), size: 30, detail: plural("count.album", list.total))
                if list.items.isEmpty {
                    EmptyState(icon: "disc", title: L("browse.no_albums"), message: L("home.empty_body"))
                } else {
                    LazyVGrid(columns: columns, spacing: 18) {
                        ForEach(Array(list.items.enumerated()), id: \.element.id) { index, album in
                            GridCard(title: album.title, subtitle: album.artistName, seed: album.title,
                                     artwork: album.artworkUrl ?? api.derivedArtwork("albums", id: album.id)) {
                                model.push(.album(id: album.id, title: album.title))
                            }
                            .onAppear { list.appeared(index, model) }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    PagedFooter(list: list) { plural("count.album", $0) }
                }
            } else if let error = list.error {
                LoadFailed(message: error) { list.error = nil; Task { await list.reload(model) } }
            } else {
                PageSkeleton()
            }
        }
        .task { if !list.loaded { await list.reload(model) } }
    }
}

/// Every artist, A to Z: "Xem tất cả" from Khám phá's artist shelf.
struct ArtistsScreen: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var api: IndieAPI
    @StateObject private var list = PagedLoader<Artist>(path: "artists")

    var body: some View {
        Page(title: L("browse.artists"), refresh: { await list.reload(model) }) {
            if list.loaded {
                PageTitle(text: L("browse.artists"), size: 30, detail: plural("count.artist", list.total))
                if list.items.isEmpty {
                    EmptyState(icon: "disc", title: L("browse.no_artists"), message: L("home.empty_body"))
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(list.items.enumerated()), id: \.element.id) { index, artist in
                            MediaRow(title: artist.name, subtitle: songCount(artist.trackCount ?? 0), seed: artist.name,
                                     artwork: artist.artworkUrl ?? api.derivedArtwork("artists", id: artist.id), octagon: true) {
                                model.push(.artist(id: artist.id, name: artist.name))
                            }
                            .onAppear { list.appeared(index, model) }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 12)
                    PagedFooter(list: list) { plural("count.artist", $0) }
                }
            } else if let error = list.error {
                LoadFailed(message: error) { list.error = nil; Task { await list.reload(model) } }
            } else {
                PageSkeleton()
            }
        }
        .task { if !list.loaded { await list.reload(model) } }
    }
}

/// A list loaded 24 at a time (`GET albums`, `GET artists`). The next page
/// loads as the end comes near; after a failed page, only from the button.
@MainActor final class PagedLoader<Item: Decodable & Identifiable>: ObservableObject {
    @Published private(set) var items: [Item] = []
    @Published private(set) var loaded = false
    @Published var error: String?
    @Published private(set) var loadingMore = false
    @Published private(set) var total = 0
    @Published private(set) var page = 0
    @Published private(set) var lastPage = 1
    private var autoLoad = true
    let path: String

    init(path: String) { self.path = path }

    var hasMore: Bool { page < lastPage }

    func reload(_ model: AppModel) async {
        switch await model.run({ try await model.api.list(path, page: 1) as ListPage<Item> }) {
        case let .success(response):
            items = []
            append(response)
            loaded = true
            error = nil
            autoLoad = true
        case let .failure(failure):
            guard !model.isCancellation(failure), model.api.signedIn else { return }
            if loaded { model.show(model.message(for: failure), error: true) } else { error = model.message(for: failure) }
        }
    }

    /// Each item calls this as it appears; ten from the end, the next page loads.
    func appeared(_ index: Int, _ model: AppModel) {
        if autoLoad && hasMore && index >= items.count - 10 { Task { await more(model) } }
    }

    func more(_ model: AppModel) async {
        guard !loadingMore, hasMore else { return }
        loadingMore = true
        let next = page + 1
        let result = await model.run { try await model.api.list(path, page: next) as ListPage<Item> }
        loadingMore = false
        switch result {
        case let .success(response):
            append(response)
            autoLoad = true
        case let .failure(failure):
            autoLoad = false
            if !model.isCancellation(failure) { model.show(model.message(for: failure), error: true) }
        }
    }

    /// Adds a page, dropping items already shown.
    private func append(_ response: ListPage<Item>) {
        var seen = Set(items.map(\.id))
        items += response.data.filter { seen.insert($0.id).inserted }
        page = response.meta?.currentPage ?? page + 1
        lastPage = response.meta?.lastPage ?? page
        total = response.meta?.total ?? items.count
    }
}

/// "Tải thêm" while pages remain, then "Đã hiện hết 86 album".
struct PagedFooter<Item: Decodable & Identifiable>: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var list: PagedLoader<Item>
    let count: (Int) -> String

    var body: some View {
        Group {
            if list.hasMore {
                PillButton(title: L("browse.load_more"), kind: .secondary, height: 46, busy: list.loadingMore,
                           busyTitle: L("browse.loading")) { Task { await list.more(model) } }
            } else {
                Text(L("browse.end", count(list.items.count)))
                    .font(.ih(.mono, 11))
                    .foregroundStyle(Theme.faint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
}
