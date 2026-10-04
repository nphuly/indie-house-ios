import SwiftUI

/// Two-letter VI | EN toggle for the connect and sign-in screens.
struct LanguageToggle: View {
    @ObservedObject private var language = AppLanguage.shared

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppLanguage.supported, id: \.self) { code in
                let active = code == language.code
                Button { language.set(code) } label: {
                    Text(code.uppercased())
                        .font(.ih(.mono, 12, relativeTo: .caption))
                        .foregroundStyle(active ? Theme.ink : Theme.muted)
                        .frame(width: 38, height: 30)
                        .background(active ? Theme.text : Color.clear)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(active ? L("common.selected", L("language.\(code)")) : L("language.\(code)"))
                .accessibilityAddTraits(active ? [.isSelected] : [])
            }
        }
        .overlay(Rectangle().strokeBorder(Theme.line))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L("language.label"))
    }
}
