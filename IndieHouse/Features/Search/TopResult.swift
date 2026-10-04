import SwiftUI

/// Same rule as the web: an artist whose name contains the query wins, then a song, an album, an artist.
struct TopResult: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var player: MusicPlayer
    let query: String
    let data: SearchResult

    private struct Pick {
        let kind: String
        let title: String
        var byline: String?
        let seed: String
        let artwork: URL?
        var octagon = false
        var queue: [Track] = []
        var context: String?
        var label: String = ""
        let open: () -> Void
    }

    var body: some View {
        let pick = choose()
        let playing = pick.context != nil && player.current != nil && player.contextId == pick.context && player.isPlaying
        SectionHeading(title: L("search.top_result"))
        Button(action: pick.open) {
            VStack(alignment: .leading, spacing: 0) {
                ArtworkView(seed: pick.seed, title: pick.title, url: pick.artwork, octagon: pick.octagon)
                    .frame(width: 92, height: 92)
                Text(pick.title)
                    .font(.ih(.bold, 24, relativeTo: .title2))
                    .foregroundStyle(Theme.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .padding(.top, 14)
                    .padding(.trailing, 64)
                HStack(spacing: 8) {
                    Text(upper(pick.kind))
                        .font(.ih(.mono, 10))
                        .foregroundStyle(Theme.text)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.bg)
                    if let byline = pick.byline {
                        Text(byline).font(.ih(.regular, 14)).foregroundStyle(Theme.soft).lineLimit(1)
                    }
                }
                .padding(.top, 6)
                .padding(.trailing, 64)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(PressStyle(fill: Theme.surface, pressedFill: Theme.raised))
        .accessibilityLabel(L("common.labelled", pick.kind, pick.title))
        .overlay(alignment: .bottomTrailing) {
            if let context = pick.context, !pick.queue.isEmpty {
                PlayButton(size: 52, glyph: 24, playing: playing,
                           busy: player.contextId == context && player.isLoading,
                           label: L(playing ? "player.pause_label" : "player.play_label", pick.title)) {
                    model.playContext(pick.queue, context: context, label: pick.label)
                }
                .padding(16)
            }
        }
        .padding(.horizontal, 16)
    }

    private func choose() -> Pick {
        let needle = Format.fold(query)
        let named = data.artists.first { Format.fold($0.name).contains(needle) }
        if let artist = named ?? (data.tracks.isEmpty && data.albums.isEmpty ? data.artists.first : nil) {
            let theirs = data.tracks.filter { $0.artist?.id == artist.id }
            return Pick(kind: L("kind.artist"), title: artist.name, seed: artist.name,
                        artwork: artist.artworkUrl ?? artist.avatarUrl, octagon: true, queue: theirs,
                        context: "artist:\(artist.id)", label: artist.name) {
                model.push(.artist(id: artist.id, name: artist.name))
            }
        }
        if let track = data.tracks.first {
            let context = "search:\(query)"
            let label = L("search.context", query)
            return Pick(kind: L("kind.song"), title: track.displayTitle, byline: track.artistName, seed: track.title,
                        artwork: track.artworkUrl, queue: data.tracks, context: context, label: label) {
                model.play(data.tracks, at: 0, context: context, label: label)
            }
        }
        let album = data.albums[0]
        return Pick(kind: L("kind.album"), title: album.title, byline: album.artistName, seed: album.title,
                    artwork: album.artworkUrl) {
            model.push(.album(id: album.id, title: album.title))
        }
    }
}
