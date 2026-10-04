import SwiftUI

struct SheetView: View {
    let kind: SheetKind

    var body: some View {
        switch kind {
        case let .trackMenu(track, playlistId): TrackMenuSheet(track: track, playlistId: playlistId)
        case let .addToPlaylist(track, playlists): AddToPlaylistSheet(track: track, playlists: playlists)
        case let .playlistForm(editing, track): PlaylistFormSheet(editing: editing, track: track)
        case .queue: QueueSheet()
        }
    }
}
