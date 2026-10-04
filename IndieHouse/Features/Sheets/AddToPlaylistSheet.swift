import SwiftUI

struct AddToPlaylistSheet: View {
    @EnvironmentObject private var model: AppModel
    let track: Track
    let playlists: [Playlist]

    var body: some View {
        SheetScaffold {
            SheetTitleHeader(title: L("menu.add_to_playlist"), note: track.displayTitle)
        } content: {
            SheetItem(icon: "plus", title: L("playlist.new"), color: Theme.accent) {
                model.sheet = .playlistForm(editing: nil, track: track)
            }
            ForEach(playlists) { playlist in
                let open = playlist.isPublic ?? false
                SheetItem(icon: open ? "library" : "lock", title: playlist.title,
                          detail: "\(songCount(playlist.tracksCount ?? 0)) · \(L(open ? "playlist.public" : "playlist.private"))") {
                    model.sheet = nil
                    Task { await model.add(track, to: playlist) }
                }
            }
        }
    }
}
