import SwiftUI

struct TrackMenuSheet: View {
    let track: Track
    let playlistId: String?

    var body: some View {
        SheetScaffold {
            SheetArtHeader(track: track)
        } content: {
            TrackMenuItems(track: track, playlistId: playlistId, sheet: true)
        }
    }
}
