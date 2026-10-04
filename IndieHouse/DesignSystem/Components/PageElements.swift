import SwiftUI

struct SectionHeading: View {
    let title: String
    var note: String? = nil
    var action: String? = nil
    var onAction: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.ih(.bold, 20, relativeTo: .title3))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
            if let note { Text(note).eyebrowStyle() }
            if let action, let onAction {
                Button(action: onAction) {
                    Text(action).font(.ih(.bold, 13)).foregroundStyle(Theme.soft).padding(8)
                }
                .buttonStyle(PressStyle())
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.top, 28)
        .padding(.bottom, 10)
    }
}

/// A page title: 28 on the first page of a tab, 30 on history and settings.
struct PageTitle: View {
    let text: String
    var size: CGFloat = 28
    var detail: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text)
                .font(.display(size))
                .foregroundStyle(Theme.text)
                .accessibilityAddTraits(.isHeader)
                .titleAnchor()
            if let detail {
                Text(detail).font(.ih(.regular, 15)).foregroundStyle(Theme.soft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }
}

struct EmptyState: View {
    let icon: String
    let title: String
    var message: String? = nil
    var action: String? = nil
    var onAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            Icon(icon, size: 26)
                .foregroundStyle(Theme.accent)
                .frame(width: 60, height: 60)
                .background(CutShape().fill(Theme.raised))
            Text(title)
                .font(.ih(.bold, 18, relativeTo: .headline))
                .foregroundStyle(Theme.text)
                .multilineTextAlignment(.center)
                .padding(.top, 16)
            if let message {
                Text(message)
                    .font(.ih(.regular, 14))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.top, 6)
            }
            if let action, let onAction {
                PillButton(title: action, kind: .light, height: 44, fill: false, action: onAction)
                    .padding(.top, 18)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 28)
        .padding(.vertical, 32)
    }
}

struct Card<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: Block())
            .overlay(Block().strokeBorder(Theme.lineSoft))
    }
}

/// Release notes and artist bios: shortened past 280 characters with Read more / Show less.
struct NoteCard: View {
    let text: String
    @State private var expanded = false

    var body: some View {
        Card {
            Text(expanded || text.count <= 280 ? text : shorten(text, 280))
                .font(.ih(.regular, 15))
                .foregroundStyle(Theme.soft)
                .lineSpacing(3)
            if text.count > 280 {
                Button(L(expanded ? "common.show_less" : "common.read_more")) { expanded.toggle() }
                    .font(.ih(.bold, 14))
                    .foregroundStyle(Theme.text)
                    .padding(.top, 10)
            }
        }
        .padding(.horizontal, 16)
    }
}

/// Cuts text at a word boundary and adds "…".
func shorten(_ text: String, _ limit: Int) -> String {
    guard text.count > limit else { return text }
    let head = String(text.prefix(limit))
    if let space = head.lastIndex(of: " "), head.distance(from: head.startIndex, to: space) > limit / 2 {
        return head[..<space].trimmingCharacters(in: .whitespaces) + "…"
    }
    return head.trimmingCharacters(in: .whitespaces) + "…"
}
