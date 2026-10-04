import SwiftUI

/// Three bars that bounce while the current song plays, like `.eq` on the web.
struct Equalizer: View {
    let playing: Bool
    var height: CGFloat = 11
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<3, id: \.self) { bar in
                EqualizerBar(duration: [0.43, 0.56, 0.38][bar], delay: Double(bar) * 0.09,
                             moving: playing && !reduceMotion, height: height)
            }
        }
        .frame(height: height)
        .accessibilityLabel(L("player.now_playing"))
    }
}

private struct EqualizerBar: View {
    let duration: Double
    let delay: Double
    let moving: Bool
    let height: CGFloat
    @State private var high = false

    var body: some View {
        Rectangle()
            .fill(Theme.accent)
            .frame(width: 3, height: height)
            .scaleEffect(x: 1, y: moving ? (high ? 1 : 0.25) : 0.6, anchor: .bottom)
            .onAppear { start() }
            .onChange(of: moving) { start() }
    }

    private func start() {
        guard moving else {
            withAnimation(.default) { high = false }
            return
        }
        withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true).delay(delay)) { high = true }
    }
}
