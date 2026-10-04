import SwiftUI

/// The terms of use or privacy policy, the same text as the library's
/// /terms and /privacy pages, in the app's language.
struct LegalScreen: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var api: IndieAPI
    /// "terms" or "privacy".
    let document: String
    @State private var text: LegalDocument?
    @State private var error: String?

    var body: some View {
        let title = text?.title ?? L("legal.\(document)")
        Page(title: title, refresh: { await load() }) {
            PageTitle(text: title, size: 30, detail: text?.updated)
            if let text {
                content(text)
            } else if let error {
                LoadFailed(message: error) { Task { await load() } }
            } else {
                SkeletonRows(count: 6)
            }
        }
        .task { if text == nil { await load() } }
    }

    /// Not a `Loader`: the invitation form shows this before sign-in.
    private func load() async {
        switch await model.run({ try await api.legal(document) }) {
        case let .success(value):
            text = value
            error = nil
        case let .failure(failure):
            guard !model.isCancellation(failure) else { return }
            if text == nil { error = model.message(for: failure) } else { model.show(model.message(for: failure), error: true) }
        }
    }

    private func content(_ text: LegalDocument) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            paragraph(text.intro).padding(.top, 20)
            ForEach(Array(text.sections.enumerated()), id: \.offset) { _, section in
                heading(section.title)
                ForEach(Array(section.paragraphs.enumerated()), id: \.offset) { _, line in
                    paragraph(line).padding(.bottom, 10)
                }
                ForEach(Array(section.items.enumerated()), id: \.offset) { _, item in
                    bullet(item).padding(.bottom, 10)
                }
            }
            heading(text.contact.title)
            paragraph(text.contact.text)
            if let email = text.contact.email, let mail = URL(string: "mailto:\(email)") {
                Link(email, destination: mail)
                    .font(.ih(.bold, 15))
                    .foregroundStyle(Theme.text)
                    .frame(minHeight: 44)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }

    private func heading(_ title: String) -> some View {
        Text(title)
            .font(.ih(.bold, 19, relativeTo: .title3))
            .foregroundStyle(Theme.text)
            .accessibilityAddTraits(.isHeader)
            .padding(.top, 18)
            .padding(.bottom, 10)
    }

    private func paragraph(_ line: String) -> some View {
        Text(line)
            .font(.ih(.regular, 15))
            .foregroundStyle(Theme.soft)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func bullet(_ item: LegalDocument.Item) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Rectangle().fill(Theme.accent).frame(width: 5, height: 5)
                .alignmentGuide(.firstTextBaseline) { $0[.bottom] + 4 }
            VStack(alignment: .leading, spacing: 2) {
                if let label = item.label {
                    Text(label).font(.ih(.bold, 15)).foregroundStyle(Theme.text)
                }
                paragraph(item.text)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// "By creating an account, you agree to the Terms of use…" with both
/// documents as links, as on the web's invitation form.
struct LegalConsent: View {
    let open: (String) -> Void

    var body: some View {
        let line = L("join.consent")
        Text((try? AttributedString(markdown: line)) ?? AttributedString(line))
            .font(.ih(.regular, 13))
            .foregroundStyle(Theme.muted)
            .tint(Theme.text)
            .fixedSize(horizontal: false, vertical: true)
            .environment(\.openURL, OpenURLAction { url in
                guard url.scheme == "legal", let document = url.host, ["terms", "privacy"].contains(document) else {
                    return .discarded
                }
                open(document)
                return .handled
            })
    }
}

/// Which document a sheet shows.
struct LegalSheet: Identifiable {
    let id: String
}
