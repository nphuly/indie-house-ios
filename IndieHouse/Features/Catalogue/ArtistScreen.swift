import SwiftUI

struct ArtistScreen: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var api: IndieAPI
    let id: String
    let name: String
    @StateObject private var loader = Loader<Artist>()
    @State private var tint = HeroTint()
    @State private var expanded = false

    var body: some View {
        let artist = loader.data
        let title = artist?.name ?? name
        Page(title: title, tint: artist == nil ? nil : tint.color(seed: title), refresh: { await load() }) {
            if let artist {
                content(artist)
            } else if let error = loader.error {
                LoadFailed(message: error) { loader.error = nil; Task { await load() } }
            } else {
                PageSkeleton(detail: true)
            }
        }
        .task { if loader.data == nil { await load() } }
    }

    private func load() async {
        await loader.load(model) { try await api.get("artists/\(id)") }
        if let tracks = loader.data?.tracks { model.remember(tracks) }
    }

    @ViewBuilder
    private func content(_ artist: Artist) -> some View {
        let tracks = artist.tracks ?? []
        let context = "artist:\(artist.id)"
        let releases = AppModel.albums(of: tracks)
        DetailHero(eyebrow: L("kind.artist"), title: artist.name, tint: tint.color(seed: artist.name), coverSize: 168) {
            ArtworkView(seed: artist.name, title: artist.name, url: artist.avatarUrl ?? artist.artworkUrl, octagon: true) {
                tint.loaded = Theme.ambient(of: $0)
            }
        } meta: {
            Text(L("common.pair", songCount(tracks.count), plural("count.album", releases.count)))
                .font(.ih(.mono, 12))
                .foregroundStyle(Theme.muted)
                .padding(.top, 8)
        }
        ActionBar(tracks: tracks, context: context, label: artist.name)
        SectionHeading(title: L("artist.popular"))
        TrackList(tracks: expanded ? tracks : Array(tracks.prefix(5)), queue: tracks, context: context,
                  label: artist.name, numbered: true)
        if tracks.count > 5 {
            Button { expanded.toggle() } label: {
                Text(expanded ? L("common.show_less") : plural("count.more_songs", tracks.count - 5))
                    .font(.ih(.bold, 14))
                    .foregroundStyle(Theme.soft)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
            .buttonStyle(PressStyle())
            .padding(.leading, 4)
            .padding(.top, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        if !releases.isEmpty {
            SectionHeading(title: L("artist.releases"))
            AlbumShelf(albums: releases)
        }
        if let bio = artist.bio?.trimmingCharacters(in: .whitespacesAndNewlines), !bio.isEmpty {
            SectionHeading(title: L("common.about"))
            NoteCard(text: bio)
        }
        Footer()
    }
}
