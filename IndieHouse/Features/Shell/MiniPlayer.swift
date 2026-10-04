import SwiftUI

struct MiniPlayer: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var player: MusicPlayer
    @State private var ambient: Color?
    @State private var ambientFor: String?

    var body: some View {
        if let track = player.current {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Button { model.playerOpen = true } label: {
                        HStack(spacing: 10) {
                            ArtworkView(seed: track.title, title: track.title, url: track.artworkUrl) { image in
                                ambient = Theme.ambient(of: image)
                                ambientFor = track.id
                                player.setArtwork(image, for: track.id)
                            }
                            .frame(width: 40, height: 40)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(track.displayTitle).font(.ih(.bold, 14)).foregroundStyle(Theme.text).lineLimit(1)
                                Text(player.failed ? L("player.mini_failed") : track.artistName)
                                    .font(.ih(.regular, 12))
                                    .foregroundStyle(player.failed ? Theme.danger : Theme.soft)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 4)
                        }
                        .padding(.leading, 8)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L("player.open"))
                    .accessibilityValue(L("common.labelled", track.displayTitle, track.artistName))
                    IconButton(icon: player.isPlaying ? "pause" : "play",
                               label: L(player.isPlaying ? "player.pause" : "player.play"),
                               size: 48, glyph: 24, busy: player.isLoading) { player.toggle() }
                        .padding(.trailing, 4)
                }
                MiniProgress(clock: player.clock).padding(.horizontal, 8)
            }
            .background(background(for: track), in: Block())
        }
    }

    private func background(for track: Track) -> Color {
        guard ambientFor == track.id, let ambient else { return Theme.raised }
        return RGB.of(ambient).mix(RGB.of(Theme.raised), 0.45).color
    }
}

private struct MiniProgress: View {
    @ObservedObject var clock: PlaybackClock

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Theme.text.opacity(0.14)
                Theme.accent.frame(width: geometry.size.width * clock.fraction)
            }
        }
        .frame(height: 2)
        .accessibilityHidden(true)
    }
}
