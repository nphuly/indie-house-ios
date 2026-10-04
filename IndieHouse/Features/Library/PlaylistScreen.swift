import SwiftUI

struct PlaylistScreen: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var api: IndieAPI
    let id: String
    let title: String
    @StateObject private var loader = Loader<Playlist>()
    @State private var tint = HeroTint()

    var body: some View {
        let playlist = loader.data
        let seed = "playlist:\(id)"
        Page(title: playlist?.title ?? title, tint: playlist == nil ? nil : tint.color(seed: seed), refresh: { await load() }) {
            if let playlist {
                content(playlist)
            } else if let error = loader.error {
                LoadFailed(message: error) { loader.error = nil; Task { await load() } }
            } else {
                PageSkeleton(detail: true)
            }
        }
        .task { if loader.data == nil { await load() } }
        .onChange(of: model.libraryVersion) { Task { await load() } }
    }

    private func load() async {
        await loader.load(model) { try await api.get("playlists/\(id)") }
        if let tracks = loader.data?.tracks { model.remember(tracks) }
    }

    @ViewBuilder
    private func content(_ playlist: Playlist) -> some View {
        let tracks = playlist.tracks ?? []
        let context = playlist.seed
        let seconds = tracks.compactMap(\.durationSeconds).reduce(0, +)
        let open = playlist.isPublic ?? false
        DetailHero(eyebrow: L(open ? "playlist.kind_public" : "playlist.kind_private"), title: playlist.title,
                   tint: tint.color(seed: playlist.seed)) {
            PlaylistCover(playlist: playlist) { tint.loaded = Theme.ambient(of: $0) }
        } meta: {
            if let about = playlist.description?.trimmingCharacters(in: .whitespacesAndNewlines), !about.isEmpty {
                Text(shorten(about, 160)).font(.ih(.regular, 14)).foregroundStyle(Theme.soft).padding(.top, 6)
            }
            Text(seconds > 0 ? L("common.pair", songCount(tracks.count), Format.length(seconds)) : songCount(tracks.count))
                .font(.ih(.mono, 12))
                .foregroundStyle(Theme.muted)
                .padding(.top, 8)
        }
        ActionBar(tracks: tracks, context: context, label: playlist.title) {
            IconButton(icon: "pencil", label: L("playlist.edit"), tint: Theme.soft) {
                model.sheet = .playlistForm(editing: playlist, track: nil)
            }
            IconButton(icon: "trash", label: L("playlist.delete"), tint: Theme.soft) { model.deletePlaylist(playlist) }
        }
        if tracks.isEmpty {
            EmptyState(icon: "note", title: L("playlist.empty_title"), message: L("playlist.empty_body"),
                       action: L("playlist.find_songs")) { model.switchTo(.search) }
        } else {
            TrackList(tracks: tracks, context: context, label: playlist.title, playlistId: playlist.id)
        }
        Footer()
    }
}
