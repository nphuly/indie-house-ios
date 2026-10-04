import SwiftUI

/// Signed-in shell: four tabs, each with its own stack, the mini player above
/// the tab bar, toasts, sheets and the full-screen player.
struct MainShell: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var player: MusicPlayer
    /// A tab is built the first time it is shown, then kept with its stack and scroll positions.
    @State private var opened: Set<Tab> = []

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                ForEach(Tab.allCases) { tab in
                    if opened.contains(tab) || model.tab == tab {
                        NavigationStack(path: $model.paths[tab.rawValue]) {
                            TabRoot(tab: tab)
                                .navigationDestination(for: Route.self) { RouteView(route: $0) }
                        }
                        .opacity(model.tab == tab ? 1 : 0)
                        .allowsHitTesting(model.tab == tab)
                        .accessibilityHidden(model.tab != tab)
                        .onAppear { opened.insert(tab) }
                    }
                }
            }
            .overlay(alignment: .bottom) { ToastHost() }
            if player.current != nil {
                MiniPlayer()
                    .padding(.horizontal, 8)
                    .padding(.top, 2)
                    .padding(.bottom, 6)
                    .transition(.opacity)
            }
            TabBar()
        }
        .background(Theme.bg.ignoresSafeArea())
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .fullScreenCover(isPresented: $model.playerOpen) { PlayerScreen() }
        .sheet(item: model.sheetBinding(forPlayer: false)) { SheetView(kind: $0) }
    }
}

extension AppModel {
    /// Sheets show over the player while it is open, otherwise over the shell.
    func sheetBinding(forPlayer: Bool) -> Binding<SheetKind?> {
        Binding(get: { self.playerOpen == forPlayer ? self.sheet : nil },
                set: { if self.playerOpen == forPlayer { self.sheet = $0 } })
    }
}

private struct TabRoot: View {
    let tab: Tab

    var body: some View {
        switch tab {
        case .home: HomeScreen()
        case .search: SearchScreen()
        case .browse: BrowseScreen()
        case .library: LibraryScreen()
        }
    }
}

struct RouteView: View {
    let route: Route

    var body: some View {
        switch route {
        case let .album(id, title): AlbumScreen(id: id, title: title)
        case let .artist(id, name): ArtistScreen(id: id, name: name)
        case let .playlist(id, title): PlaylistScreen(id: id, title: title)
        case .history: HistoryScreen()
        case .albums: AlbumsScreen()
        case .artists: ArtistsScreen()
        case .settings: SettingsScreen()
        case let .legal(document): LegalScreen(document: document)
        }
    }
}
