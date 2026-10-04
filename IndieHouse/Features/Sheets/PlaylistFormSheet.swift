import SwiftUI

/// Create and edit share one sheet: name, description and a public switch.
struct PlaylistFormSheet: View {
    @EnvironmentObject private var model: AppModel
    let editing: Playlist?
    let track: Track?
    @State private var name = ""
    @State private var note = ""
    @State private var isPublic = false
    @State private var busy = false
    @State private var error: String?
    @FocusState private var noteFocused: Bool

    var body: some View {
        SheetScaffold(allowLarge: true) {
            SheetTitleHeader(title: L(editing == nil ? "playlist.create" : "playlist.edit"),
                             note: editing == nil ? L("playlist.create_note") : nil)
        } content: {
            VStack(alignment: .leading, spacing: 16) {
                InputField(label: L("playlist.name"), icon: "note", text: $name,
                           placeholder: L("playlist.name_hint"), submitLabel: .done)
                    .onChange(of: name) { if name.count > 120 { name = String(name.prefix(120)) } }
                VStack(alignment: .leading, spacing: 8) {
                    Text(upper(L("playlist.description"))).eyebrowStyle()
                    TextField("", text: $note, prompt: Text(L("playlist.optional")).foregroundStyle(Theme.faint),
                              axis: .vertical)
                        .lineLimit(2...4)
                        .font(.ih(.regular, 16))
                        .tint(Theme.accent)
                        .focused($noteFocused)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Theme.field, in: Block())
                        .overlay(Block().strokeBorder(noteFocused ? Theme.accent : Theme.line))
                        .accessibilityLabel(L("playlist.description"))
                        .onChange(of: note) { if note.count > 1000 { note = String(note.prefix(1000)) } }
                }
                Toggle(isOn: $isPublic) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("playlist.public")).font(.ih(.bold, 15))
                        Text(L("playlist.public_hint")).font(.ih(.regular, 13)).foregroundStyle(Theme.muted)
                    }
                }
                .toggleStyle(SignToggleStyle())
                .padding(.top, 2)
                FormError(message: error)
                PillButton(title: L(editing != nil ? "playlist.save_changes" : track != nil ? "playlist.create_and_add" : "playlist.create"),
                           busy: busy, busyTitle: L(editing != nil ? "playlist.saving" : "playlist.creating")) { submit() }
                PillButton(title: L("common.cancel"), kind: .ghost, height: 44) { model.sheet = nil }
                    .padding(.top, -10)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 8)
        }
        .onAppear {
            name = editing?.title ?? ""
            note = editing?.description ?? ""
            isPublic = editing?.isPublic ?? false
        }
    }

    private func submit() {
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.count >= 2 else {
            withAnimation { error = L("playlist.name_too_short") }
            return
        }
        error = nil
        busy = true
        Task {
            do {
                try await model.savePlaylist(editing: editing, track: track, title: title,
                                             description: note.trimmingCharacters(in: .whitespacesAndNewlines),
                                             isPublic: isPublic)
            } catch {
                busy = false
                withAnimation { self.error = model.message(for: error) }
            }
        }
    }
}
