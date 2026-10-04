import SwiftUI

struct HomeScreen: View {
    @EnvironmentObject private var model: AppModel
    @State private var error: String?

    var body: some View {
        Page(title: Tab.home.title, root: .home, refresh: { await load() }) {
            if let home = model.home {
                content(home)
            } else if let error {
                LoadFailed(message: error) { self.error = nil; Task { await load() } }
            } else {
                PageSkeleton()
            }
        }
        .task { if model.home == nil { await load() } }
        .onChange(of: model.libraryVersion) { Task { await load() } }
        .onChange(of: model.refresh[Tab.home.rawValue]) { Task { await load() } }
    }

    private func load() async {
        switch await model.run({ try await model.loadHome() }) {
        case .success: error = nil
        case let .failure(failure):
            guard !model.isCancellation(failure), model.api.signedIn else { return }
            if model.home == nil { error = model.message(for: failure) }
            else { model.show(model.message(for: failure), error: true) }
        }
    }

    @ViewBuilder
    private func content(_ home: HomeData) -> some View {
        let tracks = home.catalogue
        let recent = home.library.recentTracks
        let playlists = home.library.playlists
        PageTitle(text: greeting)
        if !recent.isEmpty || !playlists.isEmpty { quickGrid(recent: recent, playlists: playlists) }
        if tracks.isEmpty {
            EmptyState(icon: "disc", title: L("home.empty_title"), message: L("home.empty_body"))
        } else {
            Spotlight(tracks: tracks)
            if !home.albums.isEmpty {
                SectionHeading(title: L("home.new_albums"), action: L("common.see_all")) { model.push(.albums) }
                AlbumShelf(albums: home.albums)
            }
            if !recent.isEmpty {
                SectionHeading(title: L("home.recent"), action: recent.count > 4 ? L("common.see_all") : nil) {
                    model.push(.history)
                }
                TrackList(tracks: Array(recent.prefix(4)), queue: recent, context: "home:recent", label: L("home.recent"))
            }
            let chart = Array(tracks.prefix(8))
            SectionHeading(title: L("home.popular"))
            TrackList(tracks: chart, context: "home:top", label: L("home.popular"), numbered: true)
            let artists = AppModel.artists(of: tracks)
            if !artists.isEmpty {
                SectionHeading(title: L("home.artists"))
                ArtistShelf(artists: artists)
            }
        }
        Footer()
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let part = (5..<11).contains(hour) ? "morning" : (11..<13).contains(hour) ? "noon"
            : (13..<18).contains(hour) ? "afternoon" : "evening"
        return L("greeting.\(part)")
    }

    private func quickGrid(recent: [Track], playlists: [Playlist]) -> some View {
        var tiles: [AnyView] = []
        if !recent.isEmpty {
            tiles.append(AnyView(QuickTile(title: L("home.recent"), seed: "history", icon: "history", context: "history") {
                model.push(.history)
            }))
        }
        for playlist in playlists where tiles.count < 6 {
            tiles.append(AnyView(QuickTile(title: playlist.title, seed: playlist.seed, context: "playlist:\(playlist.id)") {
                model.push(.playlist(id: playlist.id, title: playlist.title))
            }))
        }
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(tiles.indices, id: \.self) { tiles[$0] }
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
    }
}

/// "Nghe nhiều nhất": the most played song over the record-shop drawing.
struct Spotlight: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var player: MusicPlayer
    let tracks: [Track]

    var body: some View {
        let top = tracks[0]
        let playing = player.current != nil && player.contextId == "home:spotlight" && player.isPlaying
        ZStack(alignment: .bottomLeading) {
            Image("ConnectHero").resizable().scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .accessibilityHidden(true)
            LinearGradient(colors: [Theme.bg.opacity(0.15), Theme.bg.opacity(0.55), Theme.bg.opacity(0.94)],
                           startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 0) {
                Text(upper(L("home.most_played")))
                    .font(.ih(.mono, 11))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 7)
                    .padding(.top, 4)
                    .padding(.bottom, 3)
                    .background(Theme.pink)
                Text(top.displayTitle)
                    .font(.display(30))
                    .foregroundStyle(Theme.text)
                    .lineLimit(2)
                    .padding(.top, 6)
                Text([top.artistName, top.genreName].compactMap { $0 }.joined(separator: " · "))
                    .font(.ih(.semibold, 14))
                    .foregroundStyle(Theme.soft)
                    .lineLimit(1)
                    .padding(.top, 4)
                HStack(spacing: 12) {
                    PlayButton(size: 52, glyph: 24, playing: playing,
                               busy: player.contextId == "home:spotlight" && player.isLoading,
                               label: L(playing ? "player.pause_label" : "player.play_label", top.displayTitle)) {
                        model.playContext(tracks, context: "home:spotlight", label: L("home.popular"))
                    }
                    if let album = top.firstAlbum {
                        PillButton(title: L("home.open_album"), kind: .secondary, height: 40, fill: false) {
                            model.push(.album(id: album.id, title: album.title))
                        }
                    }
                }
                .padding(.top, 16)
            }
            .padding(18)
        }
        .frame(height: 244)
        .background(Theme.surface)
        .clipShape(Block())
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
}
