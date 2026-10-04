import SwiftUI

/// 44×28 switch: yellow when on with an ink knob, `hover` when off.
struct SignToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack(spacing: 12) {
                configuration.label.frame(maxWidth: .infinity, alignment: .leading)
                ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                    Block().fill(configuration.isOn ? Theme.accent : Theme.hover)
                    Rectangle()
                        .fill(configuration.isOn ? Theme.ink : Theme.soft)
                        .frame(width: 20, height: 20)
                        .padding(4)
                }
                .frame(width: 44, height: 28)
                .animation(.quick, value: configuration.isOn)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// A radio card: quality and language choices.
struct ChoiceCard: View {
    let title: String
    var hint: String? = nil
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 1)
                        .strokeBorder(selected ? Theme.accent : Theme.faint, lineWidth: 2)
                    if selected { Rectangle().fill(Theme.accent).frame(width: 8, height: 8) }
                }
                .frame(width: 18, height: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.ih(.bold, 15)).foregroundStyle(Theme.text)
                    if let hint { Text(hint).font(.ih(.regular, 13)).foregroundStyle(Theme.muted) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(selected ? Theme.accentWash : Theme.surface, in: Block())
            .overlay(Block().strokeBorder(selected ? Theme.accent : Theme.lineSoft))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(selected ? L("common.selected", title) : title)
        .accessibilityHint(hint ?? "")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// A 50-high input with an icon, an eyebrow label above and a yellow border while focused.
struct InputField: View {
    let label: String?
    let icon: String
    @Binding var text: String
    var placeholder = ""
    var secure = false
    var content: UITextContentType? = nil
    var keyboard: UIKeyboardType = .default
    var submitLabel: SubmitLabel = .next
    var onSubmit: () -> Void = {}
    @State private var revealed = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let label { Text(upper(label)).eyebrowStyle() }
            HStack(spacing: 10) {
                Icon(icon, size: 20).foregroundStyle(Theme.muted)
                Group {
                    if secure && !revealed {
                        SecureField("", text: $text, prompt: prompt)
                    } else {
                        TextField("", text: $text, prompt: prompt)
                    }
                }
                .font(.ih(.regular, 16))
                .foregroundStyle(Theme.text)
                .tint(Theme.accent)
                .textContentType(content)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(submitLabel)
                .onSubmit(onSubmit)
                .focused($focused)
                .accessibilityLabel(label ?? placeholder)
                if secure {
                    Button { revealed.toggle() } label: {
                        Icon(revealed ? "eye-off" : "eye", size: 20).foregroundStyle(Theme.muted)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(HaloStyle())
                    .accessibilityLabel(L(revealed ? "login.hide_password" : "login.show_password"))
                }
            }
            .padding(.leading, 14)
            .padding(.trailing, secure ? 4 : 14)
            .frame(height: 50)
            .background(Theme.field, in: Block())
            .overlay(Block().strokeBorder(focused ? Theme.accent : Theme.line))
        }
    }

    private var prompt: Text { Text(placeholder).foregroundStyle(Theme.faint) }
}

/// A form error shown right under the form, never in a dialog.
struct FormError: View {
    let message: String?

    var body: some View {
        if let message {
            HStack(alignment: .top, spacing: 8) {
                Icon("alert", size: 16).foregroundStyle(Theme.danger)
                Text(message).font(.ih(.regular, 13)).foregroundStyle(Theme.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .transition(.opacity)
        }
    }
}
