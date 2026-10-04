import SwiftUI

/// A page: top bar, loading strip and a scroll view. The first page of a tab
/// shows the wordmark and the account avatar; other pages a back button and
/// a title that fades in once the page title scrolls under the bar.
struct Page<Content: View>: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let title: String
    /// Set on the first page of a tab.
    var root: Tab? = nil
    /// Detail pages take the hero's colour.
    var tint: Color? = nil
    var refresh: (() async -> Void)? = nil
    @ViewBuilder let content: Content
    @State private var titleShown = false

    var body: some View {
        let bar = root == nil ? tint ?? Theme.bg : Theme.bg
        VStack(spacing: 0) {
            TopBar(title: title, root: root != nil, titleShown: titleShown, back: { dismiss() })
                .background(bar.ignoresSafeArea(edges: .top))
            LoadingStrip(active: model.loading > 0).background(bar)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        Color.clear.frame(height: 0).id("top")
                            .background(GeometryReader { geometry in
                                Color.clear.preference(key: ScrollTopKey.self, value: geometry.frame(in: .named("page")).minY)
                            })
                        content
                    }
                    .padding(.bottom, 16)
                }
                .scrollIndicators(.hidden)
                .coordinateSpace(name: "page")
                .modifier(Refreshable(action: refresh))
                .onPreferenceChange(TitleAnchorKey.self) { y in
                    let show = y < 0
                    if show != titleShown { withAnimation(.quick) { titleShown = show } }
                }
                .onPreferenceChange(ScrollTopKey.self) { y in
                    if let root { model.atTop[root.rawValue] = y >= -1 }
                }
                .onChange(of: root.map { model.scrollToTop[$0.rawValue] }) {
                    withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo("top", anchor: .top) }
                }
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct ScrollTopKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct Refreshable: ViewModifier {
    let action: (() async -> Void)?
    func body(content: Content) -> some View {
        if let action {
            // A separate task: SwiftUI can cancel the refresh task when the page
            // redraws mid-refresh (the loading strip does), and a cancelled
            // request is ignored, so the old data would stay.
            content.refreshable { await Task { await action() }.value }
        } else {
            content
        }
    }
}

struct TopBar: View {
    @EnvironmentObject private var model: AppModel
    let title: String
    let root: Bool
    let titleShown: Bool
    let back: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            if root {
                Image("BrandMark").resizable().scaledToFit().frame(width: 32, height: 32)
                    .accessibilityHidden(true)
                Text("INDIE HOUSE")
                    .font(.ih(.bold, 16, relativeTo: .headline))
                    .tracking(1.6)
                    .foregroundStyle(Theme.text)
                    .padding(.leading, 8)
                    .accessibilityLabel("Indie House")
                Spacer()
                Button { model.push(.settings) } label: {
                    AccountAvatar(size: 36)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L("account.settings"))
            } else {
                IconButton(icon: "back", label: L("common.back"), size: 48, action: back)
                Text(title)
                    .font(.ih(.bold, 16, relativeTo: .headline))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .padding(.leading, 6)
                    .opacity(titleShown ? 1 : 0)
                    .accessibilityHidden(!titleShown)
                Spacer()
            }
        }
        .padding(.leading, root ? 16 : 4)
        .padding(.trailing, root ? 8 : 16)
        .frame(height: 56)
    }
}

/// Where a page's big title sits in the scroll view; the top bar fades its title in once it is gone.
struct TitleAnchorKey: PreferenceKey {
    static var defaultValue: CGFloat = .infinity
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next != .infinity { value = next }
    }
}

extension View {
    func titleAnchor() -> some View {
        background(GeometryReader { geometry in
            Color.clear.preference(key: TitleAnchorKey.self, value: geometry.frame(in: .named("page")).midY)
        })
    }
}
