import SwiftUI

/// Floats 10 above the mini player (or tab bar); fades and slides up 8.
struct ToastHost: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack {
            if let toast = model.toast {
                HStack(spacing: 10) {
                    Icon(toast.error ? "alert" : "check", size: 18)
                        .foregroundStyle(toast.error ? Theme.danger : Theme.accent)
                    Text(toast.message)
                        .font(.ih(.semibold, 14))
                        .foregroundStyle(Theme.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Theme.hover, in: Block())
                .overlay(Block().strokeBorder(Theme.line))
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
                .transition(.opacity.combined(with: .offset(y: 8)))
                .id(toast.id)
                .accessibilityElement(children: .combine)
                .onAppear { UIAccessibility.post(notification: .announcement, argument: toast.message) }
            }
        }
        .allowsHitTesting(false)
    }
}
