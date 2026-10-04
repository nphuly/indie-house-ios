import SwiftUI

@main struct IndieHouseApp: App {
    @StateObject private var language = AppLanguage.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.locale, language.locale)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
    }
}
