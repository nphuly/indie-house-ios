import SwiftUI

/// The hero's colour: from the artwork once it loads, from the seed's tone before that.
struct HeroTint {
    var loaded: Color?
    func color(seed: String) -> Color { loaded ?? Theme.ambient(tone: Theme.tone(seed)) }
}

/// Shuffle and page actions on the left, the yellow play button on the right.
struct ActionBar<Extra: View>: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var player: MusicPlayer
    let tracks: [Track]
    let context: String
    let label: String
    @ViewBuilder var extra: Extra

    var body: some View {
        let playing = player.current != nil && player.contextId == context && player.isPlaying
        HStack(spacing: 4) {
            IconButton(icon: "shuffle", label: L("player.shuffle"), tint: Theme.soft) {
                model.play(tracks, at: 0, context: context, label: label, shuffled: true)
            }
            .disabled(tracks.isEmpty)
            extra
            Spacer()
            PlayButton(size: 56, glyph: 26, playing: playing,
                       busy: player.contextId == context && player.isLoading,
                       label: L(playing ? "player.pause_label" : "player.play_label", label)) {
                model.playContext(tracks, context: context, label: label)
            }
            .disabled(tracks.isEmpty)
        }
        .padding(.leading, 12)
        .padding(.trailing, 16)
        .padding(.vertical, 8)
    }
}

extension ActionBar where Extra == EmptyView {
    init(tracks: [Track], context: String, label: String) {
        self.init(tracks: tracks, context: context, label: label) { EmptyView() }
    }
}

/// Hero of album, artist and playlist pages: artwork over a tint taken from it.
struct DetailHero<Cover: View, Meta: View>: View {
    let eyebrow: String
    let title: String
    let tint: Color
    var coverSize: CGFloat = 184
    @ViewBuilder var cover: Cover
    @ViewBuilder var meta: Meta

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cover
                .frame(width: coverSize, height: coverSize)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .padding(.bottom, 20)
            Text(upper(eyebrow)).eyebrowStyle(Theme.soft)
            Text(title)
                .font(.display(heroSize))
                .foregroundStyle(Theme.text)
                .lineLimit(3)
                .padding(.top, 6)
                .accessibilityAddTraits(.isHeader)
                .titleAnchor()
            meta
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(LinearGradient(colors: [tint, Theme.bg], startPoint: .top, endPoint: .bottom))
    }

    /// Long names shrink: over 18 characters ×0.8, over 34 ×0.66.
    private var heroSize: CGFloat { title.count > 34 ? 30 * 0.66 : title.count > 18 ? 30 * 0.8 : 30 }
}
