import SwiftUI

/// A card on a horizontal shelf: 140 wide; artists are octagons.
struct MediaCard: View {
    let title: String
    let subtitle: String
    let seed: String
    let artwork: URL?
    var octagon = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                ArtworkView(seed: seed, title: title, url: artwork, octagon: octagon)
                    .frame(width: 140, height: 140)
                Text(title).font(.ih(.bold, 14)).foregroundStyle(Theme.text).lineLimit(1).padding(.top, 8)
                Text(subtitle).font(.ih(.regular, 12)).foregroundStyle(Theme.muted).lineLimit(1).padding(.top, 1)
            }
            .frame(width: 140, alignment: .leading)
            .padding(.bottom, 4)
        }
        .buttonStyle(PressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("common.labelled", subtitle, title))
        .accessibilityAddTraits(.isButton)
    }
}

/// A card in a two-column grid: square artwork as wide as the column.
struct GridCard: View {
    let title: String
    let subtitle: String
    let seed: String
    let artwork: URL?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                ArtworkView(seed: seed, title: title, url: artwork)
                    .aspectRatio(1, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                Text(title).font(.ih(.bold, 14)).foregroundStyle(Theme.text).lineLimit(1).padding(.top, 8)
                Text(subtitle).font(.ih(.regular, 12)).foregroundStyle(Theme.muted).lineLimit(1).padding(.top, 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(PressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("common.labelled", subtitle, title))
        .accessibilityAddTraits(.isButton)
    }
}

/// Playlists, albums and artists as a list row: 56 artwork, name and detail.
struct MediaRow<Detail: View>: View {
    let title: String
    let seed: String
    var artwork: URL? = nil
    var octagon = false
    var accessibility: String? = nil
    @ViewBuilder var detail: Detail
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ArtworkView(seed: seed, title: title, url: artwork, octagon: octagon)
                    .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.ih(.bold, 15)).foregroundStyle(Theme.text).lineLimit(1)
                    detail
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .buttonStyle(PressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibility ?? title)
    }
}

extension MediaRow where Detail == Text {
    init(title: String, subtitle: String, seed: String, artwork: URL? = nil, octagon: Bool = false,
         action: @escaping () -> Void) {
        self.init(title: title, seed: seed, artwork: artwork, octagon: octagon,
                  accessibility: L("common.labelled", subtitle, title),
                  detail: { Text(subtitle).font(.ih(.regular, 13)).foregroundStyle(Theme.muted) },
                  action: action)
    }
}

struct Shelf<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 12) { content }
                .padding(.horizontal, 16)
        }
    }
}

struct AlbumShelf: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var api: IndieAPI
    let albums: [Album]

    var body: some View {
        Shelf {
            ForEach(albums) { album in
                MediaCard(title: album.title, subtitle: "\(L("kind.album")) · \(album.artistName)", seed: album.title,
                          artwork: album.artworkUrl ?? api.derivedArtwork("albums", id: album.id)) {
                    model.push(.album(id: album.id, title: album.title))
                }
            }
        }
    }
}

struct ArtistShelf: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var api: IndieAPI
    let artists: [Artist]

    var body: some View {
        Shelf {
            ForEach(artists) { artist in
                MediaCard(title: artist.name, subtitle: L("kind.artist"), seed: artist.name,
                          artwork: artist.artworkUrl ?? artist.avatarUrl ?? api.derivedArtwork("artists", id: artist.id),
                          octagon: true) {
                    model.push(.artist(id: artist.id, name: artist.name))
                }
            }
        }
    }
}
