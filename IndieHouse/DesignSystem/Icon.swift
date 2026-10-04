import SwiftUI

/// The web's icon set (`App\Support\Icon`), exported as template PDFs by
/// indie-house-server/scripts/generate-legacy-android-assets.py. Always tinted with one colour.
struct Icon: View {
    let name: String
    var size: CGFloat = 22

    init(_ name: String, size: CGFloat = 22) {
        self.name = name
        self.size = size
    }

    var body: some View {
        Image("icon-\(name)")
            .renderingMode(.template)
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
