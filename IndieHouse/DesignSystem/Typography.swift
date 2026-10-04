import SwiftUI

/// Chakra Petch 400/600/700 and JetBrains Mono 400 (SIL OFL 1.1), bundled in `Fonts/`.
/// Sizes follow the spec at the default text size and scale with Dynamic Type.
enum Typeface {
    case regular, semibold, bold, mono

    var name: String {
        switch self {
        case .regular: "ChakraPetch-Regular"
        case .semibold: "ChakraPetch-SemiBold"
        case .bold: "ChakraPetch-Bold"
        case .mono: "JetBrainsMono-Regular"
        }
    }
}

extension Font {
    static func ih(_ face: Typeface, _ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(face.name, size: size, relativeTo: style)
    }

    static func display(_ size: CGFloat) -> Font { .ih(.bold, size, relativeTo: .largeTitle) }
}

extension View {
    /// Mono eyebrow: upper case in the chosen language.
    func eyebrowStyle(_ color: Color = Theme.muted, size: CGFloat = 11) -> some View {
        font(.ih(.mono, size, relativeTo: .caption2)).foregroundStyle(color)
    }
}
