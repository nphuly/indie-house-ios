import SwiftUI

struct ConnectView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var api: IndieAPI
    @State private var address = UserDefaults.standard.string(forKey: "server_url") ?? ""
    @State private var busy = false
    @State private var error: String?
    @State private var scanning = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                AuthHero()
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("INDIE HOUSE").font(.ih(.bold, 18)).tracking(1.8)
                        Spacer()
                        LanguageToggle()
                    }
                    Text(L("connect.title"))
                        .font(.display(28))
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, 18)
                    Text(L("connect.lede"))
                        .font(.ih(.regular, 15))
                        .foregroundStyle(Theme.soft)
                        .lineSpacing(2)
                        .padding(.top, 8)
                    InputField(label: L("connect.address"), icon: "globe", text: $address,
                               placeholder: "https://music.example.com", content: .URL, keyboard: .URL,
                               submitLabel: .go) { discover() }
                        .padding(.top, 24)
                    FormError(message: error).padding(.top, 12)
                    PillButton(title: L("connect.button"), busy: busy, busyTitle: L("connect.checking")) { discover() }
                        .padding(.top, 16)
                    PillButton(title: L("connect.scan"), icon: "qr", kind: .secondary) { scanning = true }
                        .padding(.top, 10)
                    Text(L("connect.note"))
                        .font(.ih(.regular, 13))
                        .foregroundStyle(Theme.muted)
                        .padding(.top, 16)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .ignoresSafeArea(edges: .top)
        .fullScreenCover(isPresented: $scanning) {
            QRScanView { value in
                scanning = false
                address = value
                discover()
            }
        }
    }

    private func discover() {
        guard !busy else { return }
        error = nil
        busy = true
        Task {
            defer { busy = false }
            do {
                let candidate = try await api.discover(address)
                UserDefaults.standard.set(address, forKey: "server_url")
                model.confirm = ConfirmRequest(
                    title: L("connect.confirm_title", candidate.name),
                    message: L("connect.confirm_body", candidate.origin.host ?? candidate.origin.absoluteString),
                    action: L("connect.button"), destructive: false) {
                    do { try api.trust(candidate) } catch { withAnimation { self.error = model.message(for: error) } }
                }
            } catch {
                withAnimation { self.error = model.message(for: error) }
            }
        }
    }
}
