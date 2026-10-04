import SwiftUI

struct TabBar: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases) { tab in
                let active = model.tab == tab
                Button { model.select(tab) } label: {
                    VStack(spacing: 3) {
                        Icon(tab.icon, size: 24)
                        Text(tab.title)
                            .font(.ih(active ? .semibold : .regular, 11, relativeTo: .caption2))
                            .lineLimit(1)
                    }
                    .foregroundStyle(active ? Theme.accent : Theme.muted)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .contentShape(Rectangle())
                }
                .buttonStyle(TabPressStyle())
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(active ? [.isSelected] : [])
            }
        }
        .background(Theme.bg.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Theme.lineSoft.frame(height: 1) }
    }
}

private struct TabPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.background(alignment: .top) {
            Circle().fill(configuration.isPressed ? Theme.pressed : .clear)
                .frame(width: 44, height: 44)
                .offset(y: -3)
        }
    }
}
