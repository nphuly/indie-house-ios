import SwiftUI

/// A quick-access tile on Home: 56 high, two to a row.
struct QuickTile: View {
    @EnvironmentObject private var player: MusicPlayer
    let title: String
    let seed: String
    var icon: String? = nil
    var context: String? = nil
    let action: () -> Void

    var body: some View {
        let live = context != nil && player.current != nil && player.contextId == context
        Button(action: action) {
            HStack(spacing: 0) {
                ArtworkView(seed: seed, title: title, url: nil, icon: icon)
                    .frame(width: 56, height: 56)
                Text(title)
                    .font(.ih(.bold, 13))
                    .foregroundStyle(live ? Theme.accent : Theme.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 56)
        }
        .buttonStyle(PressStyle(fill: Theme.raised, pressedFill: Theme.hover))
        .accessibilityLabel(title)
    }
}

/// A genre tile in Search: 92 high with a gradient from the genre's tone.
struct GenreTile: View {
    let name: String
    let count: Int
    let action: () -> Void

    var body: some View {
        let tone = Theme.tone(name.lowercased())
        let base = Theme.toneBase(tone)
        let accent = Theme.toneAccent(tone)
        Button(action: action) {
            ZStack(alignment: .bottomTrailing) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(.ih(.bold, 17)).foregroundStyle(Theme.text).lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(songCount(count)).font(.ih(.mono, 11)).foregroundStyle(Theme.text.opacity(0.7))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                Icon("signal", size: 30).foregroundStyle(accent.color.opacity(0.8)).padding(12)
            }
            .frame(height: 92)
            .background(LinearGradient(colors: [base.mix(accent, 0.28).color, base.color],
                                       startPoint: .topLeading, endPoint: .bottomTrailing), in: Block())
        }
        .buttonStyle(TileStyle(pressed: base.mix(accent, 0.4).color))
        .accessibilityLabel(L("common.pair", name, songCount(count)))
    }
}

private struct TileStyle: ButtonStyle {
    let pressed: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.overlay(Block().fill(configuration.isPressed ? pressed.opacity(0.5) : .clear))
    }
}
