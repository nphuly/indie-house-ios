import SwiftUI
import UIKit

/// The account's picture in an octagon: the profile picture uploaded on the
/// web when there is one, otherwise the user glyph on pink.
struct AccountAvatar: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var api: IndieAPI
    var size: CGFloat = 36
    @State private var loaded: UIImage?

    var body: some View {
        let url = model.account?.avatarUrl
        ZStack {
            if let picture = api.cachedImage(url) ?? loaded {
                Image(uiImage: picture)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
            } else {
                Theme.pink
                Icon("user", size: size / 2).foregroundStyle(Theme.ink)
            }
        }
        .frame(width: size, height: size)
        .clipShape(OctagonShape())
        .accessibilityHidden(true)
        .task(id: url) { loaded = await api.image(url) }
    }
}
