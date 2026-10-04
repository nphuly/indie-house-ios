import SwiftUI

struct Footer: View {
    @EnvironmentObject private var api: IndieAPI

    var body: some View {
        HStack(spacing: 8) {
            Image("BrandMark").resizable().scaledToFit().frame(width: 18, height: 18)
            Text(api.profile?.origin.host ?? "").font(.ih(.mono, 11)).foregroundStyle(Theme.faint)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 36)
        .padding(.bottom, 28)
        .accessibilityHidden(true)
    }
}
