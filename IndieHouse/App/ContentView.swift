import SwiftUI

/// Start-up, connect and sign-in, then the signed-in shell.
struct ContentView: View {
    @StateObject private var model = AppModel()
    @ObservedObject private var language = AppLanguage.shared

    var body: some View {
        Root()
            .environmentObject(model)
            .environmentObject(model.api)
            .environmentObject(model.player)
            // Rebuilt in the chosen language when it changes. The API client and
            // the player live on the model, so music keeps playing.
            .id(language.code)
    }
}

struct Root: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var api: IndieAPI
    // Kept on the model: switching language rebuilds this view.
    private var stage: Stage {
        get { model.stage }
        nonmutating set { model.stage = newValue }
    }
    private var notice: Binding<String?> { $model.notice }
    @State private var restoring = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            switch stage {
            case .starting: StartupView(problem: nil, retry: {}, change: {})
            case let .failed(problem):
                StartupView(problem: problem, retry: { Task { await restore() } }, change: {
                    Task {
                        stage = .starting
                        await api.disconnect()
                        stage = .auth
                    }
                })
            case .auth:
                if api.profile == nil { ConnectView() } else { LoginView(notice: notice) { signedIn() } }
            case .app:
                MainShell()
            }
            ConfirmOverlay()
        }
        .foregroundStyle(Theme.text)
        .tint(Theme.accent)
        .task { if stage == .starting && !restoring { await restore() } }
        .onChange(of: api.signedIn) {
            // A rejected session or a sign-out returns to sign-in; music stops.
            if !api.signedIn && stage == .app {
                model.leaveApp()
                if api.sessionExpired { model.notice = L("session.expired") }
                stage = .auth
            }
        }
        .onChange(of: api.profile == nil) { if api.profile == nil && stage == .app { model.leaveApp(); stage = .auth } }
    }

    private func restore() async {
        restoring = true
        defer { restoring = false }
        stage = .starting
        do {
            try await api.restore()
            guard api.signedIn else {
                stage = .auth
                return
            }
            _ = try await model.loadHome()
            signedIn()
        } catch {
            if api.sessionExpired || !api.signedIn && api.profile != nil && (error as? IndieAPI.APIStatus) == .unauthorized {
                model.notice = L("session.expired")
                stage = .auth
            } else {
                stage = .failed(model.message(for: error))
            }
        }
    }

    private func signedIn() {
        model.notice = nil
        api.sessionExpired = false
        model.enterApp()
        stage = .app
    }
}
