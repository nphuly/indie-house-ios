import SwiftUI

/// Pressed overlay for rows, cards and links.
struct PressStyle: ButtonStyle {
    var fill: Color = .clear
    var pressedFill: Color = Theme.pressed

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? pressedFill : fill, in: Block())
            .contentShape(Rectangle())
    }
}

enum PillKind { case primary, secondary, ghost, danger, light }

struct PillStyle: ButtonStyle {
    let kind: PillKind
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let shape = CutShape(fixed: 9)
        configuration.label
            .foregroundStyle(foreground)
            .background {
                switch kind {
                case .primary: shape.fill(pressed ? Theme.accentBright : Theme.accent)
                case .secondary: shape.strokeBorder(Theme.text.opacity(pressed ? 1 : 0.32), lineWidth: 1)
                case .ghost: shape.fill(pressed ? Theme.pressed : .clear)
                case .danger: shape.fill(Theme.dangerWash.opacity(pressed ? 1.5 : 1))
                case .light: shape.fill(pressed ? Theme.soft : Theme.text)
                }
            }
            .contentShape(shape)
            .opacity(enabled ? 1 : (kind == .primary ? 0.72 : 0.5))
    }

    private var foreground: Color {
        switch kind {
        case .primary, .light: Theme.ink
        case .secondary, .ghost: Theme.text
        case .danger: Theme.danger
        }
    }
}

struct PillButton: View {
    let title: String
    var icon: String? = nil
    var kind: PillKind = .primary
    var height: CGFloat = 48
    var fill = true
    var busy = false
    var busyTitle: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if busy {
                    ProgressView().controlSize(.small)
                        .tint(kind == .primary || kind == .light ? Theme.ink : Theme.accent)
                        .frame(width: 18, height: 18)
                } else if let icon {
                    Icon(icon, size: 20)
                }
                Text(busy ? busyTitle ?? title : title)
                    .font(.ih(.bold, 15))
                    .lineLimit(1)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: fill ? .infinity : nil, minHeight: height)
        }
        .buttonStyle(PillStyle(kind: kind))
        .allowsHitTesting(!busy)
        .accessibilityAddTraits(busy ? .updatesFrequently : [])
    }
}

/// Plain icon buttons get a round pressed halo.
struct HaloStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Circle().fill(configuration.isPressed ? Theme.pressed : .clear))
            .contentShape(Rectangle())
    }
}

struct IconButton: View {
    let icon: String
    let label: String
    var size: CGFloat = 44
    var glyph: CGFloat = 22
    var tint: Color = Theme.text
    /// A yellow dot under the glyph, e.g. shuffle on.
    var active = false
    var badge: String? = nil
    var busy = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if busy {
                    ProgressView().tint(Theme.accent).frame(width: 24, height: 24)
                } else {
                    Icon(icon, size: glyph).foregroundStyle(tint)
                }
                if active {
                    Rectangle().fill(Theme.accent).frame(width: 4, height: 4)
                        .offset(y: glyph / 2 + 6)
                }
                if let badge {
                    Text(badge)
                        .font(.ih(.bold, 9))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 13, height: 13)
                        .background(Theme.accent)
                        .offset(x: glyph / 2 + 2, y: -glyph / 2)
                }
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(HaloStyle())
        .accessibilityLabel(label)
    }
}

/// The yellow play button: 52 on cards, 56 in action bars, 68 in the player.
struct PlayButton: View {
    var size: CGFloat = 56
    var glyph: CGFloat = 26
    let playing: Bool
    var busy = false
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if busy {
                    ProgressView().tint(Theme.ink)
                } else {
                    Icon(playing ? "pause" : "play", size: glyph).foregroundStyle(Theme.ink)
                }
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(PlayStyle())
        .accessibilityLabel(label)
    }
}

private struct PlayStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(CutShape().fill(configuration.isPressed ? Theme.accentBright : Theme.accent))
            .contentShape(CutShape())
            .opacity(enabled ? 1 : 0.5)
    }
}

struct Chip: View {
    let title: String
    var active = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.ih(active ? .bold : .semibold, 13))
                .foregroundStyle(active ? Theme.ink : Theme.text)
                .padding(.horizontal, 14)
                .frame(minHeight: 36)
        }
        .buttonStyle(PressStyle(fill: active ? Theme.accent : Theme.raised,
                                pressedFill: active ? Theme.accentBright : Theme.hover))
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}
