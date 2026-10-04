import SwiftUI

struct AlbumScreen: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var api: IndieAPI
    let id: String
    let title: String
    @StateObject private var loader = Loader<Album>()
    @State private var tint = HeroTint()

    var body: some View {
        let album = loader.data
        let name = album?.title ?? title
        Page(title: name, tint: album == nil ? nil : tint.color(seed: name), refresh: { await load() }) {
            if let album {
                content(album)
            } else if let error = loader.error {
                LoadFailed(message: error) { loader.error = nil; Task { await load() } }
            } else {
                PageSkeleton(detail: true)
            }
        }
        .task { if loader.data == nil { await load() } }
    }

    private func load() async {
        await loader.load(model) { try await api.get("albums/\(id)") }
        if let tracks = loader.data?.tracks { model.remember(tracks) }
    }

    @ViewBuilder
    private func content(_ album: Album) -> some View {
        let tracks = album.tracks ?? []
        let context = "album:\(album.id)"
        let seconds = tracks.compactMap(\.durationSeconds).reduce(0, +)
        DetailHero(eyebrow: L("kind.album"), title: album.title, tint: tint.color(seed: album.title)) {
            ArtworkView(seed: album.title, title: album.title, url: album.artworkUrl) { tint.loaded = Theme.ambient(of: $0) }
        } meta: {
            HStack(spacing: 0) {
                if let artist = album.artist {
                    Button { model.push(.artist(id: artist.id, name: artist.name)) } label: {
                        HStack(spacing: 8) {
                            ArtworkView(seed: artist.name, title: artist.name,
                                        url: api.derivedArtwork("artists", id: artist.id), octagon: true)
                                .frame(width: 22, height: 22)
                            Text(artist.name).font(.ih(.bold, 14)).foregroundStyle(Theme.text).lineLimit(1)
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
                Text(" · " + L("common.pair", songCount(tracks.count), Format.length(seconds)))
                    .font(.ih(.mono, 12))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            .padding(.top, 6)
        }
        ActionBar(tracks: tracks, context: context, label: album.title)
        if tracks.isEmpty {
            EmptyState(icon: "disc", title: L("album.empty"))
        } else {
            TrackList(tracks: tracks, context: context, label: album.title, numbered: true, showArt: false)
        }
        if let about = album.description?.trimmingCharacters(in: .whitespacesAndNewlines), !about.isEmpty {
            SectionHeading(title: L("common.about"))
            NoteCard(text: about)
        }
        Footer()
    }
}
