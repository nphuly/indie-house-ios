import SwiftUI
import UIKit

/// Artwork frame, like the web `art` component and the Leap `ArtView`:
/// without artwork a tinted placeholder whose tone comes from a seed, so an
/// item keeps its colour everywhere; loaded artwork fades in under a light
/// hologram layer. One cut corner, or an octagon for artists.
struct ArtworkView: View {
    @EnvironmentObject private var api: IndieAPI
    let seed: String?
    let title: String?
    let url: URL?
    var octagon = false
    /// An icon instead of the first letter, e.g. `history` for "Recently played".
    var icon: String? = nil
    var onImage: ((UIImage) -> Void)? = nil

    @State private var loaded: UIImage?
    @State private var loadedFor: URL?
    /// Set while artwork that was not cached fades in (220ms).
    @State private var fading: URL?
    @State private var visible = false

    var body: some View {
        let image = api.cachedImage(url) ?? (loadedFor == url ? loaded : nil)
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            ZStack {
                ArtPlaceholder(seed: seed, title: title, icon: icon, side: side)
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .overlay(Hologram())
                        // Cached artwork shows at once; new artwork fades in.
                        .opacity(fading == url && !visible ? 0 : 1)
                }
            }
        }
        .clipShape(octagon ? AnyShape(OctagonShape()) : AnyShape(ArtShape()))
        .accessibilityHidden(true)
        .task(id: url) {
            if let cached = api.cachedImage(url) {
                fading = nil
                onImage?(cached)
                return
            }
            fading = url
            visible = false
            loaded = nil
            loadedFor = url
            guard let image = await api.image(url), !Task.isCancelled else { return }
            loaded = image
            withAnimation(.easeOut(duration: 0.22)) { visible = true }
            onImage?(image)
        }
    }
}

struct ArtPlaceholder: View {
    let seed: String?
    let title: String?
    var icon: String?
    let side: CGFloat

    var body: some View {
        let tone = Theme.tone(seed)
        let accent = Theme.toneAccent(tone)
        let initial = title?.trimmingCharacters(in: .whitespaces).first.map { String($0).uppercased() }
        ZStack {
            LinearGradient(colors: [Theme.toneBase(tone).color, Color(hex: 0x0C1017)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [accent.color.opacity(0.42), accent.color.opacity(0)],
                           center: UnitPoint(x: 0.85, y: 0.08), startRadius: 0, endRadius: max(1, side * 1.1))
            if let glyph = icon ?? (initial == nil ? "note" : nil) {
                Icon(glyph, size: side * 0.42).foregroundStyle(accent.color)
            } else if let initial {
                Text(initial)
                    .font(.custom(Typeface.mono.name, fixedSize: min(side * 0.38, 72)))
                    .foregroundStyle(accent.mix(RGB(r: 1, g: 1, b: 1), 0.25).color.opacity(0.85))
            }
        }
    }
}

/// Faint scanlines, a cyan-to-pink tint and a thin colour fringe, as `.art` on the web.
struct Hologram: View {
    var body: some View {
        Canvas { context, size in
            let bounds = CGRect(origin: .zero, size: size)
            context.fill(Path(bounds), with: .linearGradient(
                Gradient(stops: [.init(color: Theme.cyan.opacity(0.09), location: 0),
                                 .init(color: .clear, location: 0.42),
                                 .init(color: .clear, location: 0.64),
                                 .init(color: Theme.pink.opacity(0.09), location: 1)]),
                startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)))
            var y: CGFloat = 0
            let line = Color(hex: 0xD6FAFF).opacity(0.07)
            while y < size.height {
                context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: .color(line))
                y += 3
            }
            context.fill(Path(CGRect(x: 0, y: 0, width: 2, height: size.height)), with: .color(Theme.pink.opacity(0.24)))
            context.fill(Path(CGRect(x: size.width - 2, y: 0, width: 2, height: size.height)),
                         with: .color(Theme.cyan.opacity(0.24)))
        }
        .allowsHitTesting(false)
    }
}

/// A playlist cover: a 2×2 mosaic from four songs, the first song's cover, or the seeded placeholder.
struct PlaylistCover: View {
    let playlist: Playlist
    var onImage: ((UIImage) -> Void)? = nil

    var body: some View {
        let tracks = playlist.tracks ?? []
        if tracks.count >= 4 {
            Grid(horizontalSpacing: 4, verticalSpacing: 4) {
                ForEach(0..<2, id: \.self) { row in
                    GridRow {
                        ForEach(0..<2, id: \.self) { column in
                            let track = tracks[row * 2 + column]
                            ArtworkView(seed: track.title, title: track.title, url: track.artworkUrl,
                                        onImage: row == 0 && column == 0 ? onImage : nil)
                        }
                    }
                }
            }
        } else {
            ArtworkView(seed: playlist.seed, title: playlist.title, url: tracks.first?.artworkUrl, onImage: onImage)
        }
    }
}
