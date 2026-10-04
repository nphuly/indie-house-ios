import SwiftUI

struct HistoryScreen: View {
    @EnvironmentObject private var model: AppModel
    @StateObject private var loader = Loader<LibraryData>()

    var body: some View {
        Page(title: L("home.recent"), refresh: { await load() }) {
            if let library = loader.data {
                let recent = library.recentTracks
                PageTitle(text: L("home.recent"), size: 30)
                if recent.isEmpty {
                    EmptyState(icon: "history", title: L("library.history_empty_title"),
                               message: L("library.history_empty_body"), action: Tab.browse.title) { model.switchTo(.browse) }
                } else {
                    ActionBar(tracks: recent, context: "history", label: L("home.recent"))
                    TrackList(tracks: recent, context: "history", label: L("home.recent"), numbered: true)
                }
            } else if let error = loader.error {
                LoadFailed(message: error) { loader.error = nil; Task { await load() } }
            } else {
                PageSkeleton()
            }
        }
        .task { if loader.data == nil { await load() } }
        .onChange(of: model.libraryVersion) { Task { await load() } }
    }

    private func load() async { await loader.load(model) { try await model.api.get("library") } }
}
