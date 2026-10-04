import SwiftUI

struct QueueSheet: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var player: MusicPlayer

    var body: some View {
        let start = max(0, player.index)
        let end = min(player.queue.count, start + 41)
        SheetScaffold {
            SheetTitleHeader(title: L("player.queue"),
                             note: player.contextLabel.map { L("player.playing_from_label", $0) })
        } content: {
            ForEach(start..<end, id: \.self) { position in
                let track = player.queue[position]
                let current = position == player.index
                SheetItem(icon: current ? "signal" : "note", title: track.displayTitle,
                          detail: current ? L("player.queue_now", track.artistName) : "\(position - start) · \(track.artistName)",
                          color: current ? Theme.accent : Theme.text,
                          action: current ? nil : {
                              model.sheet = nil
                              player.jump(to: position)
                          })
            }
            if player.queue.count - start <= 1 {
                Text(L("player.queue_empty"))
                    .font(.ih(.regular, 14))
                    .foregroundStyle(Theme.muted)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
            }
        }
    }
}
