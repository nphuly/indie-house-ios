import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var api: IndieAPI
    @Binding var notice: String?
    let done: () -> Void
    @State private var inviteMode = false
    @State private var invite = ""
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var busy = false
    @State private var error: String?
    @State private var legal: LegalSheet?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                AuthHero()
                    .overlay(alignment: .topTrailing) {
                        LanguageToggle().padding(.trailing, 20).padding(.top, 60)
                    }
                VStack(alignment: .leading, spacing: 0) {
                    libraryCard
                    Text(L(inviteMode ? "join.title" : "login.title"))
                        .font(.display(28))
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, 24)
                    Text(L(inviteMode ? "join.lede" : "login.lede"))
                        .font(.ih(.regular, 15))
                        .foregroundStyle(Theme.soft)
                        .padding(.top, 8)
                    VStack(spacing: 16) {
                        if inviteMode {
                            InputField(label: L("login.invite_code"), icon: "key", text: $invite,
                                       placeholder: L("login.invite_hint"), content: .oneTimeCode)
                            InputField(label: L("login.name"), icon: "user", text: $name,
                                       placeholder: L("login.name_hint"), content: .name)
                        }
                        InputField(label: L("login.email"), icon: "mail", text: $email, placeholder: L("login.email_hint"),
                                   content: .username, keyboard: .emailAddress)
                        InputField(label: L("login.password"), icon: "lock", text: $password, secure: true,
                                   content: inviteMode ? .newPassword : .password, submitLabel: .go) { submit() }
                    }
                    .padding(.top, 24)
                    FormError(message: error ?? notice).padding(.top, 12)
                    if inviteMode {
                        LegalConsent { legal = LegalSheet(id: $0) }.padding(.top, 12)
                    }
                    PillButton(title: L(inviteMode ? "join.submit" : "login.submit"), busy: busy,
                               busyTitle: L(inviteMode ? "join.busy" : "login.busy")) { submit() }
                        .padding(.top, 16)
                    if api.profile?.registrationMode == "invite_only" {
                        Button(L(inviteMode ? "login.have_account" : "login.have_invite")) {
                            withAnimation { inviteMode.toggle(); error = nil }
                        }
                        .font(.ih(.bold, 14))
                        .foregroundStyle(Theme.text)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding(.top, 6)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .ignoresSafeArea(edges: .top)
        .sheet(item: $legal) { LegalScreen(document: $0.id) }
    }

    private var libraryCard: some View {
        HStack(spacing: 12) {
            Image("BrandMark").resizable().scaledToFit().frame(width: 44, height: 44).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(api.profile?.name ?? "").font(.ih(.bold, 16)).lineLimit(1)
                Text(api.profile?.origin.host ?? "").font(.ih(.mono, 12)).foregroundStyle(Theme.muted).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(L("library.change")) {
                Task { await api.disconnect() }
            }
            .font(.ih(.bold, 13))
            .foregroundStyle(Theme.soft)
            .frame(minHeight: 44)
        }
        .padding(12)
        .background(Theme.surface, in: Block())
        .overlay(Block().strokeBorder(Theme.lineSoft))
    }

    private func submit() {
        guard !busy else { return }
        let email = email.trimmingCharacters(in: .whitespaces)
        let invite = invite.trimmingCharacters(in: .whitespaces)
        let name = name.trimmingCharacters(in: .whitespaces)
        if inviteMode && (invite.isEmpty || name.isEmpty) { return fail(L("login.need_invite_name")) }
        if email.isEmpty || password.isEmpty { return fail(L("login.need_email_password")) }
        error = nil
        notice = nil
        busy = true
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        Task {
            do {
                if inviteMode {
                    try await api.redeem(code: invite, name: name, email: email, password: password)
                } else {
                    try await api.login(email: email, password: password)
                }
                _ = try await model.loadHome()
                password = ""
                busy = false
                done()
            } catch {
                busy = false
                fail(model.message(for: error))
            }
        }
    }

    private func fail(_ message: String) {
        withAnimation { error = message }
    }
}
