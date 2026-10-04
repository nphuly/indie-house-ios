import SwiftUI

/// Only for destructive actions and confirming a connection.
struct ConfirmOverlay: View {
    @EnvironmentObject private var model: AppModel
    @State private var shown = false

    var body: some View {
        ZStack {
            if let request = model.confirm {
                Color.black.opacity(0.64)
                    .ignoresSafeArea()
                    .onTapGesture { close() }
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 0) {
                    Text(request.title)
                        .font(.ih(.bold, 19, relativeTo: .title3))
                        .foregroundStyle(Theme.text)
                        .accessibilityAddTraits(.isHeader)
                    Text(request.message)
                        .font(.ih(.regular, 14))
                        .foregroundStyle(Theme.soft)
                        .padding(.top, 8)
                    HStack(spacing: 8) {
                        Spacer()
                        PillButton(title: L("common.cancel"), kind: .ghost, height: 44, fill: false) { close() }
                        PillButton(title: request.action, kind: request.destructive ? .danger : .primary,
                                   height: 44, fill: false) {
                            close()
                            request.perform()
                        }
                    }
                    .padding(.top, 20)
                }
                .padding(22)
                .frame(maxWidth: 360)
                .background(Theme.raised, in: Block())
                .overlay(Block().strokeBorder(Theme.lineSoft))
                .padding(.horizontal, 20)
                .scaleEffect(shown ? 1 : 0.94)
                .opacity(shown ? 1 : 0)
                .onAppear { withAnimation(.dialog) { shown = true } }
                .accessibilityAddTraits(.isModal)
            }
        }
    }

    private func close() {
        withAnimation(.dialog) { shown = false }
        Task {
            try? await Task.sleep(for: .milliseconds(180))
            model.confirm = nil
        }
    }
}
