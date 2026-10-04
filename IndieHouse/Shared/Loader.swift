import SwiftUI

/// Loads a page's data: a skeleton the first time, an error with Retry if
/// that fails, otherwise the old data stays while it refreshes quietly and a
/// failed refresh is reported as a toast.
@MainActor final class Loader<T>: ObservableObject {
    @Published var data: T?
    @Published var error: String?

    func load(_ model: AppModel, _ work: () async throws -> T) async {
        switch await model.run(work) {
        case let .success(value):
            data = value
            error = nil
        case let .failure(failure):
            guard !model.isCancellation(failure), model.api.signedIn else { return }
            if data == nil { error = model.message(for: failure) } else { model.show(model.message(for: failure), error: true) }
        }
    }
}

/// "Không tải được trang" with the reason and Retry.
struct LoadFailed: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        EmptyState(icon: "signal", title: L("error.load_title"), message: message, action: L("common.retry"), onAction: retry)
            .padding(.top, 40)
    }
}
