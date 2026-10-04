import SwiftUI

/// One song. Tapping plays the whole list it belongs to from this song; the
/// `more` button or a long press opens the song menu.
struct TrackRow: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var player: MusicPlayer
    let track: Track
    var number: Int? = nil
    var showArt = true
    var playlistId: String? = nil
    let play: () -> Void

    var body: some View {
        let isCurrent = player.current?.id == track.id
        HStack(spacing: 0) {
            Button(action: play) {
                HStack(spacing: 0) {
                    if let number {
                        ZStack {
                            if isCurrent { Equalizer(playing: player.isPlaying, height: 12) }
                            else {
                                Text(String(format: "%02d", number)).font(.ih(.mono, 12)).foregroundStyle(Theme.muted)
                            }
                        }
                        .frame(width: 28, height: 40)
                        .padding(.trailing, showArt ? 8 : 4)
                    }
                    if showArt {
                        ArtworkView(seed: track.title, title: track.title, url: track.artworkUrl)
                            .frame(width: 46, height: 46)
                            .padding(.trailing, 12)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            if isCurrent && number == nil { Equalizer(playing: player.isPlaying) }
                            Text(track.displayTitle)
                                .font(.ih(.semibold, 15))
                                .foregroundStyle(isCurrent ? Theme.accent : Theme.text)
                                .lineLimit(1)
                        }
                        Text(track.artistName)
                            .font(.ih(.regular, 13))
                            .foregroundStyle(Theme.muted)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                }
                .padding(.leading, 8)
                .padding(.vertical, 6)
                .frame(minHeight: 56)
            }
            .buttonStyle(PressStyle())
            .accessibilityElement(children: .combine)
            .accessibilityLabel(L("common.labelled", track.displayTitle, track.artistName))
            .accessibilityHint(L("player.play"))
            IconButton(icon: "more", label: L("player.track_options"), glyph: 20, tint: Theme.muted) {
                model.trackMenu(track, playlistId: playlistId)
            }
        }
        .contextMenu { TrackMenuItems(track: track, playlistId: playlistId) }
    }
}

/// Songs in a column with an 8 margin, so the text lines up with the 16 page margin.
struct TrackList: View {
    @EnvironmentObject private var model: AppModel
    let tracks: [Track]
    /// The whole list the rows belong to; defaults to `tracks`.
    var queue: [Track]? = nil
    let context: String
    let label: String
    var numbered = false
    var showArt = true
    var playlistId: String? = nil

    var body: some View {
        let queue = queue ?? tracks
        LazyVStack(spacing: 0) {
            ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                TrackRow(track: track, number: numbered ? index + 1 : nil, showArt: showArt, playlistId: playlistId) {
                    model.play(queue, at: queue.firstIndex(of: track) ?? index, context: context, label: label)
                }
            }
        }
        .padding(.horizontal, 8)
    }
}
