import SwiftUI

/// A 2-high strip under the top bar; a yellow segment runs across while requests are open.
struct LoadingStrip: View {
    let active: Bool

    var body: some View {
        GeometryReader { geometry in
            if active {
                TimelineView(.animation) { timeline in
                    let phase = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 0.9) / 0.9
                    let width = geometry.size.width * 0.3
                    Rectangle().fill(Theme.accent)
                        .frame(width: width, height: 2)
                        .offset(x: -width + (geometry.size.width + width) * phase)
                }
            }
        }
        .frame(height: 2)
        .clipped()
        .accessibilityHidden(true)
    }
}
