import SwiftUI

/// 4-high track, yellow played part and a white 4×14 thumb. Dragging updates
/// the times; the seek happens on release.
struct SeekBar: View {
    @ObservedObject var clock: PlaybackClock
    let enabled: Bool
    let seek: (Double) -> Void
    @State private var dragging: Double?

    var body: some View {
        let duration = max(clock.duration, 0)
        let position = min(dragging ?? clock.position, duration)
        VStack(spacing: 4) {
            GeometryReader { geometry in
                let width = geometry.size.width
                let fraction = duration > 0 ? position / duration : 0
                ZStack(alignment: .leading) {
                    Rectangle().fill(Theme.text.opacity(0.18)).frame(height: 4)
                    Rectangle().fill(Theme.accent).frame(width: width * fraction, height: 4)
                    Rectangle().fill(Theme.text).frame(width: 4, height: 14)
                        .offset(x: max(0, min(width - 4, width * fraction - 2)))
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard enabled, duration > 0 else { return }
                        dragging = max(0, min(1, value.location.x / width)) * duration
                    }
                    .onEnded { _ in
                        if let dragging { seek(dragging) }
                        dragging = nil
                    })
            }
            .frame(height: 28)
            .opacity(enabled ? 1 : 0.5)
            HStack {
                Text(Format.clock(position))
                Spacer()
                Text("-" + Format.clock(max(0, duration - position)))
            }
            .font(.ih(.mono, 11))
            .foregroundStyle(Theme.muted)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("player.seek"))
        .accessibilityValue(L("player.seek_position", Format.clock(position), Format.clock(duration)))
        .accessibilityAdjustableAction { direction in
            guard enabled else { return }
            seek(position + (direction == .increment ? 10 : -10))
        }
    }
}
