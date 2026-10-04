import SwiftUI

/// The song menu, shared by the sheet and the long-press context menu.
struct TrackMenuItems: View {
    @EnvironmentObject private var model: AppModel
    let track: Track
    var playlistId: String? = nil
    var sheet = false

    var body: some View {
        item("plus", L("menu.add_to_playlist")) { model.addToPlaylist(track) }
        item("queue", L("menu.play_next")) {
            model.sheet = nil
            model.playNext(track)
        }
        if let album = track.firstAlbum {
            item("disc", L("menu.go_album"), detail: album.title) {
                model.push(.album(id: album.id, title: album.title))
            }
        }
        if let artist = track.artist {
            item("user", L("menu.go_artist"), detail: artist.name) {
                model.push(.artist(id: artist.id, name: artist.name))
            }
        }
        if let playlistId {
            item("trash", L("menu.remove_from_playlist"), color: Theme.danger) {
                model.sheet = nil
                Task { await model.remove(track, from: playlistId) }
            }
        }
    }

    @ViewBuilder
    private func item(_ icon: String, _ title: String, detail: String? = nil, color: Color = Theme.text,
                      action: @escaping () -> Void) -> some View {
        if sheet {
            SheetItem(icon: icon, title: title, detail: detail, color: color, action: action)
        } else {
            Button(role: color == Theme.danger ? .destructive : nil, action: action) {
                Label { Text(title) } icon: { Image("icon-\(icon)").renderingMode(.template) }
            }
        }
    }
}
