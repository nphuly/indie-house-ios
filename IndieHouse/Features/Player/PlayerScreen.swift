import SwiftUI

/// Full-screen player: artwork over a blurred wash of itself, seek bar,
/// shuffle and repeat, and the queue.
struct PlayerScreen: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var player: MusicPlayer
    @State private var image: UIImage?
    @State private var imageFor: String?
    @State private var backdropShown = false

    var body: some View {
        ZStack {
            if let track = player.current {
                backdrop(for: track)
                VStack(spacing: 0) {
                    header
                    ArtworkView(seed: track.title, title: track.title, url: track.artworkUrl) { loaded in
                        image = loaded
                        imageFor = track.id
                        backdropShown = false
                        withAnimation(.easeOut(duration: 0.3)) { backdropShown = true }
                        player.setArtwork(loaded, for: track.id)
                    }
                    .aspectRatio(1, contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 16)
                    info(for: track)
                    SeekBar(clock: player.clock, enabled: !player.isLoading && !player.failed) { player.seek(to: $0) }
                        .padding(.horizontal, 12)
                        .padding(.top, 10)
                    controls
                    if player.failed { failure }
                    footer
                }
                .padding(.horizontal, 12)
                .padding(.top, 6)
                .padding(.bottom, 14)
            }
        }
        .foregroundStyle(Theme.text)
        .background(Theme.bg.ignoresSafeArea())
        .overlay(alignment: .bottom) { ToastHost() }
        .overlay { ConfirmOverlay() }
        .sheet(item: model.sheetBinding(forPlayer: true)) { SheetView(kind: $0) }
        .onChange(of: player.current == nil) { if player.current == nil { model.playerOpen = false } }
    }

    private func backdrop(for track: Track) -> some View {
        let loaded = imageFor == track.id ? image : nil
        let tint = loaded.map(Theme.ambient(of:)) ?? Theme.ambient(tone: Theme.tone(track.title))
        return ZStack {
            if let loaded {
                GeometryReader { geometry in
                    Image(uiImage: loaded)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .blur(radius: 60)
                        .clipped()
                }
                .opacity(backdropShown ? 0.55 : 0)
            }
            LinearGradient(colors: [tint.opacity(0.82), Theme.bg.opacity(0.9), Theme.bg],
                           startPoint: .top, endPoint: .bottom)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var header: some View {
        HStack(spacing: 0) {
            IconButton(icon: "chevron-down", label: L("player.minimize"), size: 48) { model.playerOpen = false }
            VStack(spacing: 1) {
                Text(upper(L("player.playing_from"))).eyebrowStyle(size: 10)
                Text(player.contextLabel.flatMap { $0.isEmpty ? nil : $0 } ?? "Indie House")
                    .font(.ih(.bold, 13))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            IconButton(icon: "more", label: L("player.track_options"), size: 48) {
                if let track = player.current { model.trackMenu(track) }
            }
        }
    }

    private func info(for track: Track) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                MarqueeText(text: track.displayTitle, font: .ih(.bold, 22, relativeTo: .title2))
                    .frame(height: 30)
                Button {
                    if let artist = track.artist { model.push(.artist(id: artist.id, name: artist.name)) }
                } label: {
                    Text(track.artistName).font(.ih(.regular, 15)).foregroundStyle(Theme.soft).lineLimit(1)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .disabled(track.artist == nil)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            IconButton(icon: "plus", label: L("menu.add_to_playlist"), size: 48) { model.addToPlaylist(track) }
        }
        .padding(.leading, 12)
    }

    private var controls: some View {
        HStack(spacing: 0) {
            IconButton(icon: "shuffle", label: L(player.shuffle ? "player.shuffle_off" : "player.shuffle"),
                       size: 48, tint: player.shuffle ? Theme.accent : Theme.text, active: player.shuffle) {
                player.setShuffle(!player.shuffle)
            }
            .frame(maxWidth: .infinity)
            IconButton(icon: "previous", label: L("player.previous"), size: 56, glyph: 28) { player.previous() }
                .frame(maxWidth: .infinity)
            PlayButton(size: 68, glyph: 30, playing: player.isPlaying, busy: player.isLoading,
                       label: L(player.isPlaying ? "player.pause" : "player.play")) { player.toggle() }
                .padding(.horizontal, 6)
            IconButton(icon: "next", label: L("player.next"), size: 56, glyph: 28) { player.next() }
                .frame(maxWidth: .infinity)
                .disabled(!player.hasNext)
                .opacity(player.hasNext ? 1 : 0.4)
            IconButton(icon: "repeat", label: L(repeatLabel), size: 48,
                       tint: player.repeatMode == .off ? Theme.text : Theme.accent,
                       active: player.repeatMode != .off,
                       badge: player.repeatMode == .one ? "1" : nil) { player.cycleRepeat() }
                .frame(maxWidth: .infinity)
        }
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    private var repeatLabel: String {
        switch player.repeatMode {
        case .off: "player.repeat_off"
        case .all: "player.repeat_all"
        case .one: "player.repeat_one"
        }
    }

    private var failure: some View {
        HStack(spacing: 10) {
            Icon("alert", size: 18).foregroundStyle(Theme.danger)
            Text(L("player.failed")).font(.ih(.regular, 13)).frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Theme.dangerWash, in: Block())
        .overlay(Block().strokeBorder(Theme.danger.opacity(0.35)))
        .padding(.horizontal, 8)
        .padding(.top, 4)
    }

    /// "FLAC · lossless", or "MP3 · 320 kbps".
    private var formatLabel: String {
        player.format == "FLAC" ? L("player.format.flac") : "MP3 · \(L("player.quality.\(player.quality)"))"
    }

    private var footer: some View {
        HStack(spacing: 0) {
            Text("\(player.index + 1) / \(player.queue.count) · \(formatLabel)")
                .font(.ih(.mono, 11))
                .foregroundStyle(Theme.faint)
                .frame(maxWidth: .infinity, alignment: .leading)
            IconButton(icon: "queue", label: L("player.queue"), size: 48) { model.sheet = .queue }
        }
        .padding(.leading, 12)
    }
}
