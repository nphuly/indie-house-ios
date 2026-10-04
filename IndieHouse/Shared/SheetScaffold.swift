import SwiftUI

/// Bottom sheet: `raised`, a 36×4 handle, as tall as its content up to 74% of the screen.
struct SheetScaffold<Header: View, Content: View>: View {
    var allowLarge = false
    @ViewBuilder var header: Header
    @ViewBuilder var content: Content
    @State private var height: CGFloat = 320

    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(Theme.text.opacity(0.22)).frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 6)
                .accessibilityHidden(true)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    content
                }
                .padding(.bottom, 12)
                .background(GeometryReader { geometry in
                    Color.clear.preference(key: SheetHeightKey.self, value: geometry.size.height)
                })
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .foregroundStyle(Theme.text)
        .onPreferenceChange(SheetHeightKey.self) { height = $0 + 20 }
        .presentationDetents(allowLarge ? [.height(detent), .large] : [.height(detent)])
        .presentationBackground(Theme.raised)
        .presentationCornerRadius(Theme.radius)
        .presentationDragIndicator(.hidden)
    }

    private var detent: CGFloat { min(height, UIScreen.main.bounds.height * 0.74) }
}

private struct SheetHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// Sheet head with artwork, name and detail.
struct SheetArtHeader: View {
    let track: Track

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(seed: track.title, title: track.title, url: track.artworkUrl).frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(track.displayTitle).font(.ih(.bold, 16)).lineLimit(1)
                Text(track.artistName).font(.ih(.regular, 13)).foregroundStyle(Theme.muted).lineLimit(1)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}

/// Sheet head with a 20 title and a 14 note.
struct SheetTitleHeader: View {
    let title: String
    var note: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.ih(.bold, 20, relativeTo: .title3)).accessibilityAddTraits(.isHeader)
            if let note { Text(note).font(.ih(.regular, 14)).foregroundStyle(Theme.muted) }
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 10)
    }
}

/// One sheet item: at least 52 high, a 22 icon and a 15 label with a 12 detail.
struct SheetItem: View {
    let icon: String
    let title: String
    var detail: String? = nil
    var color: Color = Theme.text
    var iconColor: Color? = nil
    let action: (() -> Void)?

    var body: some View {
        Button { action?() } label: {
            HStack(spacing: 16) {
                Icon(icon, size: 22).foregroundStyle(iconColor ?? (color == Theme.text ? Theme.soft : color))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.ih(.regular, 15)).foregroundStyle(color).lineLimit(2)
                    if let detail { Text(detail).font(.ih(.regular, 12)).foregroundStyle(Theme.muted).lineLimit(1) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 20)
            .frame(minHeight: 52)
        }
        .buttonStyle(PressStyle(pressedFill: Theme.hover))
        .disabled(action == nil)
    }
}
