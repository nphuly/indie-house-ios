import SwiftUI

/// Khám phá: the newest songs and albums and the most played artists, with
/// every album and artist a tap away. It never lists the whole catalogue.
struct BrowseScreen: View {
    @EnvironmentObject private var model: AppModel
    @StateObject private var loader = Loader<BrowseData>()

    var body: some View {
        Page(title: Tab.browse.title, root: .browse, refresh: { await load() }) {
            if let browse = loader.data {
                PageTitle(text: Tab.browse.title, size: 30, detail: summary(browse.counts))
                if browse.newTracks.isEmpty {
                    EmptyState(icon: "disc", title: L("home.empty_title"), message: L("home.empty_body"))
                } else {
                    content(browse)
                }
                Footer()
            } else if let error = loader.error {
                LoadFailed(message: error) { loader.error = nil; Task { await load() } }
            } else {
                PageSkeleton()
            }
        }
        .task { if loader.data == nil { await load() } }
        .onChange(of: model.refresh[Tab.browse.rawValue]) { Task { await load() } }
    }

    @ViewBuilder
    private func content(_ browse: BrowseData) -> some View {
        SectionHeading(title: L("browse.new_tracks"))
        TrackList(tracks: browse.newTracks, context: "browse:new", label: L("browse.new_tracks"))
        if !browse.albums.isEmpty {
            SectionHeading(title: L("home.new_albums"), action: L("common.see_all")) { model.push(.albums) }
            AlbumShelf(albums: browse.albums)
        }
        if !browse.artists.isEmpty {
            SectionHeading(title: L("home.artists"), action: L("common.see_all")) { model.push(.artists) }
            ArtistShelf(artists: browse.artists)
        }
    }

    /// "1240 bài hát · 86 album · 41 nghệ sĩ"
    private func summary(_ counts: BrowseData.Counts) -> String {
        [plural("count.song_long", counts.tracks), plural("count.album", counts.albums), plural("count.artist", counts.artists)]
            .joined(separator: " · ")
    }

    private func load() async {
        await loader.load(model) {
            let browse: BrowseData = try await model.api.get("browse")
            model.remember(browse.newTracks)
            return browse
        }
    }
}
