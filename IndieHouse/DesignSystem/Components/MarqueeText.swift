import SwiftUI

/// One line that scrolls when it does not fit, for the song title in the player.
struct MarqueeText: View {
    let text: String
    let font: Font
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var textWidth: CGFloat = 0
    @State private var offset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let overflow = textWidth > geometry.size.width + 1 && !reduceMotion
            let label = Text(text).font(font).lineLimit(1).fixedSize()
            ZStack(alignment: .leading) {
                if overflow {
                    HStack(spacing: 48) { label; label }
                        .offset(x: offset)
                        .onAppear { animate(distance: textWidth + 48) }
                        .onChange(of: text) { animate(distance: textWidth + 48) }
                } else {
                    Text(text).font(font).lineLimit(1).truncationMode(.tail)
                }
            }
            .frame(width: geometry.size.width, alignment: .leading)
            .clipped()
            .background(label.hidden().background(GeometryReader { measure in
                Color.clear.onAppear { textWidth = measure.size.width }
                    .onChange(of: measure.size.width) { textWidth = measure.size.width }
            }))
        }
        .accessibilityLabel(text)
    }

    private func animate(distance: CGFloat) {
        offset = 0
        withAnimation(.linear(duration: Double(distance) / 30).delay(1.5).repeatForever(autoreverses: false)) {
            offset = -distance
        }
    }
}
