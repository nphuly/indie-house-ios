import SwiftUI

struct LibraryScreen: View {
    @EnvironmentObject private var model: AppModel
    @StateObject private var loader = Loader<LibraryData>()

    var body: some View {
        Page(title: Tab.library.title, root: .library, refresh: { await load() }) {
            if let library = loader.data {
                content(library)
            } else if let error = loader.error {
                LoadFailed(message: error) { loader.error = nil; Task { await load() } }
            } else {
                PageSkeleton()
            }
        }
        .task { if loader.data == nil { await load() } }
        .onChange(of: model.libraryVersion) { Task { await load() } }
        .onChange(of: model.refresh[Tab.library.rawValue]) { Task { await load() } }
    }

    private func load() async {
        await loader.load(model) { try await model.api.get("library") }
        if let data = loader.data { model.remember(data.recentTracks) }
    }

    @ViewBuilder
    private func content(_ library: LibraryData) -> some View {
        let recent = library.recentTracks
        PageTitle(text: Tab.library.title, size: 30)
        SectionHeading(title: L("library.playlists"))
        VStack(spacing: 0) {
            Button { model.sheet = .playlistForm(editing: nil, track: nil) } label: {
                HStack(spacing: 14) {
                    Icon("plus", size: 24)
                        .foregroundStyle(Theme.accent)
                        .frame(width: 56, height: 56)
                        .background(Theme.accentWash, in: Block())
                        .overlay(Block().strokeBorder(Theme.accent.opacity(0.45)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("playlist.create")).font(.ih(.bold, 15)).foregroundStyle(Theme.text)
                        Text(L("playlist.create_hint")).font(.ih(.regular, 13)).foregroundStyle(Theme.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .buttonStyle(PressStyle())
            ForEach(library.playlists) { playlist in PlaylistRow(playlist: playlist) }
        }
        .padding(.horizontal, 8)
        SectionHeading(title: L("library.history"), action: recent.count > 10 ? L("common.see_all") : nil) {
            model.push(.history)
        }
        if recent.isEmpty {
            EmptyState(icon: "history", title: L("library.history_empty_title"), message: L("library.history_empty_body"),
                       action: Tab.browse.title) { model.switchTo(.browse) }
        } else {
            TrackList(tracks: Array(recent.prefix(10)), queue: recent, context: "library:history",
                      label: L("library.history"), numbered: true)
        }
        Footer()
    }
}

private struct PlaylistRow: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var player: MusicPlayer
    let playlist: Playlist

    var body: some View {
        let open = playlist.isPublic ?? false
        let detail = L("common.pair", songCount(playlist.tracksCount ?? 0), L(open ? "playlist.public" : "playlist.private"))
        let live = player.current != nil && player.contextId == playlist.seed
        MediaRow(title: playlist.title, seed: playlist.seed, accessibility: L("playlist.a11y", playlist.title)) {
            HStack(spacing: 5) {
                if !open { Icon("lock", size: 13).foregroundStyle(Theme.muted) }
                Text(detail).font(.ih(.regular, 13)).foregroundStyle(live ? Theme.accent : Theme.muted).lineLimit(1)
            }
        } action: {
            model.push(.playlist(id: playlist.id, title: playlist.title))
        }
    }
}
