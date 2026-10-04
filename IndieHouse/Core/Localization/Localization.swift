import Foundation
import SwiftUI

/// The listener's language choice (Vietnamese or English), kept per device like
/// the web app and the Leap client. Vietnamese is the default.
///
/// Strings live in `vi.lproj` and `en.lproj/Localizable.strings` and are read
/// from the chosen `.lproj` bundle, so switching does not wait for iOS to
/// restart the app.
final class AppLanguage: ObservableObject {
    static let shared = AppLanguage()
    static let supported = ["vi", "en"]
    private static let storageKey = "ui_locale"

    @Published private(set) var code: String
    private(set) var bundle: Bundle

    private init() {
        let saved = UserDefaults.standard.string(forKey: Self.storageKey) ?? "vi"
        let chosen = Self.supported.contains(saved) ? saved : "vi"
        code = chosen
        bundle = Self.bundle(for: chosen)
    }

    var locale: Locale { Locale(identifier: code) }

    func set(_ value: String) {
        guard Self.supported.contains(value), value != code else { return }
        UserDefaults.standard.set(value, forKey: Self.storageKey)
        bundle = Self.bundle(for: value)
        code = value
    }

    private static func bundle(for code: String) -> Bundle {
        guard let path = Bundle.main.path(forResource: code, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return .main }
        return bundle
    }
}

/// Looks up a key in the chosen language: `L("login.submit")`, `L("player.play_label", title)`.
func L(_ key: String, _ arguments: CVarArg...) -> String {
    let language = AppLanguage.shared
    let format = language.bundle.localizedString(forKey: key, value: key, table: nil)
    return arguments.isEmpty ? format : String(format: format, locale: language.locale, arguments: arguments)
}

/// `key.one` / `key.other`: "1 song" / "3 songs"; Vietnamese uses the same word for both.
func plural(_ key: String, _ count: Int) -> String { L("\(key).\(count == 1 ? "one" : "other")", count) }

func songCount(_ count: Int) -> String { plural("count.song", count) }

/// Upper case in the chosen language, for eyebrows and tags.
func upper(_ text: String) -> String { text.uppercased(with: AppLanguage.shared.locale) }
