import SwiftUI

/// The record-shop drawing, fading into the background.
struct AuthHero: View {
    var body: some View {
        Image("ConnectHero")
            .resizable()
            .scaledToFill()
            .frame(height: 220)
            .frame(maxWidth: .infinity)
            .clipped()
            .overlay(LinearGradient(colors: [Theme.bg.opacity(0), Theme.bg.opacity(0.35), Theme.bg],
                                    startPoint: .top, endPoint: .bottom))
            .accessibilityHidden(true)
    }
}
