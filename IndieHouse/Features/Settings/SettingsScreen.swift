import SwiftUI

struct SettingsScreen: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var api: IndieAPI
    @ObservedObject private var language = AppLanguage.shared
    @StateObject private var devices = Loader<[MobileDevice]>()

    var body: some View {
        Page(title: L("settings.title"), refresh: { await load() }) {
            PageTitle(text: L("settings.title"), size: 30)
            library
            playback
            languages
            deviceList
            legal
            heading(L("settings.account"))
            accountCard
            PillButton(title: L("account.logout"), icon: "logout", kind: .danger, height: 46) { model.signOut() }
                .padding(.horizontal, 16)
            Text(L("settings.version", UIDevice.current.model, version))
                .font(.ih(.mono, 11))
                .foregroundStyle(Theme.faint)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
        }
        .task { await load() }
    }

    private func load() async {
        await model.syncPreferences()
        await model.syncAccount()
        await devices.load(model) { try await api.get("devices") }
    }

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? ""
        let build = info?["CFBundleVersion"] as? String ?? ""
        return build.isEmpty || build == short ? short : "\(short) (\(build))"
    }

    private func heading(_ title: String) -> some View {
        Text(title)
            .font(.ih(.bold, 19, relativeTo: .title3))
            .foregroundStyle(Theme.text)
            .accessibilityAddTraits(.isHeader)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 12)
    }

    @ViewBuilder
    private var library: some View {
        heading(L("settings.library"))
        Card {
            HStack(spacing: 12) {
                Image("BrandMark").resizable().scaledToFit().frame(width: 26, height: 26)
                    .frame(width: 46, height: 46)
                    .background(Theme.bg, in: Block())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(api.profile?.name ?? "").font(.ih(.bold, 16)).foregroundStyle(Theme.text).lineLimit(1)
                    Text(api.profile?.origin.host ?? "").font(.ih(.mono, 12)).foregroundStyle(Theme.muted).lineLimit(1)
                }
            }
            HStack(spacing: 8) {
                Icon("shield", size: 16).foregroundStyle(Theme.accent)
                Text(L("settings.verified")).font(.ih(.regular, 13)).foregroundStyle(Theme.soft)
            }
            .padding(.top, 14)
            PillButton(title: L("library.change"), icon: "globe", kind: .secondary, height: 44) { model.changeLibrary() }
                .padding(.top, 14)
        }
        .padding(.horizontal, 16)
    }

    private var losslessAvailable: Bool { model.preferences.losslessAvailable == true }

    /// 128, 320 and, when an admin granted it, Lossless.
    private var qualityChoices: [String] {
        losslessAvailable ? ["standard", "high", "lossless"] : ["standard", "high"]
    }

    /// "auto" has always played 128 kbps; a lossless choice whose grant was revoked plays 320.
    private var shownQuality: String {
        switch model.preferences.audioQuality {
        case "auto": "standard"
        case "lossless": losslessAvailable ? "lossless" : "high"
        case let quality: quality
        }
    }

    @ViewBuilder
    private var playback: some View {
        heading(L("settings.playback"))
        VStack(spacing: 8) {
            ForEach(qualityChoices, id: \.self) { quality in
                ChoiceCard(title: L("settings.quality.\(quality)"), hint: L("settings.quality.\(quality)_hint"),
                           selected: shownQuality == quality) {
                    var updated = model.preferences
                    updated.audioQuality = quality
                    Task { await model.savePreferences(updated, key: "audio_quality", value: quality) }
                }
            }
        }
        .padding(.horizontal, 16)
        Card {
            Toggle(isOn: preference(\.autoplay, key: "autoplay")) {
                switchLabel(L("settings.autoplay"), L("settings.autoplay_hint"))
            }
            .toggleStyle(SignToggleStyle())
            Theme.lineSoft.frame(height: 1).padding(.vertical, 12)
            Toggle(isOn: preference(\.recordListeningHistory, key: "record_listening_history")) {
                switchLabel(L("settings.record_history"), L("settings.record_history_hint"))
            }
            .toggleStyle(SignToggleStyle())
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private func switchLabel(_ title: String, _ hint: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.ih(.bold, 15)).foregroundStyle(Theme.text)
            Text(hint).font(.ih(.regular, 13)).foregroundStyle(Theme.muted)
        }
    }

    private func preference(_ path: WritableKeyPath<ListeningPreferences, Bool>, key: String) -> Binding<Bool> {
        Binding(get: { model.preferences[keyPath: path] }, set: { value in
            var updated = model.preferences
            updated[keyPath: path] = value
            Task { await model.savePreferences(updated, key: key, value: value) }
        })
    }

    @ViewBuilder
    private var languages: some View {
        heading(L("language.label"))
        VStack(spacing: 8) {
            ForEach(AppLanguage.supported, id: \.self) { code in
                ChoiceCard(title: L("language.\(code)"), selected: language.code == code) { language.set(code) }
            }
        }
        .padding(.horizontal, 16)
        Text(L("language.hint"))
            .font(.ih(.regular, 13))
            .foregroundStyle(Theme.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 4)
    }

    @ViewBuilder
    private var deviceList: some View {
        heading(L("settings.devices"))
        Text(L("devices.hint"))
            .font(.ih(.regular, 14))
            .foregroundStyle(Theme.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
        if let list = devices.data {
            VStack(spacing: 0) {
                if list.isEmpty {
                    Text(L("devices.none"))
                        .font(.ih(.regular, 14))
                        .foregroundStyle(Theme.soft)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
                ForEach(list) { device in
                    HStack(spacing: 12) {
                        Icon("device", size: 20)
                            .foregroundStyle(Theme.soft)
                            .frame(width: 42, height: 42)
                            .background(Theme.raised, in: Block())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(device.deviceName.flatMap { $0.isEmpty ? nil : $0 } ?? L("devices.unknown"))
                                .font(.ih(.bold, 15)).foregroundStyle(Theme.text).lineLimit(1)
                            Text(L("devices.used", Format.relative(device.lastUsedAt)))
                                .font(.ih(.mono, 12)).foregroundStyle(Theme.muted).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        PillButton(title: L("devices.revoke"), kind: .ghost, height: 40, fill: false) { revoke(device) }
                    }
                    .padding(.leading, 12)
                    .padding(.trailing, 4)
                    .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 8)
        } else if let error = devices.error {
            FormError(message: error).padding(.horizontal, 20)
        } else {
            SkeletonRows(count: 2)
        }
    }

    @ViewBuilder
    private var accountCard: some View {
        if let account = model.account {
            Card {
                HStack(spacing: 12) {
                    AccountAvatar(size: 46)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(account.name).font(.ih(.bold, 16)).foregroundStyle(Theme.text).lineLimit(1)
                        Text(account.email).font(.ih(.mono, 12)).foregroundStyle(Theme.muted).lineLimit(1)
                    }
                }
                Text(L("settings.account_hint"))
                    .font(.ih(.regular, 13))
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 12)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }

    @ViewBuilder
    private var legal: some View {
        heading(L("settings.legal"))
        VStack(spacing: 8) {
            ForEach(["terms", "privacy"], id: \.self) { document in
                Button { model.push(.legal(document: document)) } label: {
                    HStack(spacing: 14) {
                        Icon(document == "terms" ? "note" : "shield", size: 20).foregroundStyle(Theme.soft)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L("legal.\(document)")).font(.ih(.bold, 15)).foregroundStyle(Theme.text)
                            Text(L("legal.\(document)_hint")).font(.ih(.regular, 13)).foregroundStyle(Theme.muted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Icon("chevron-down", size: 16).foregroundStyle(Theme.faint).rotationEffect(.degrees(-90))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Theme.surface, in: Block())
                    .overlay(Block().strokeBorder(Theme.lineSoft))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint(L("legal.\(document)_hint"))
            }
        }
        .padding(.horizontal, 16)
    }

    private func revoke(_ device: MobileDevice) {
        model.confirm = ConfirmRequest(title: L("devices.revoke_title"), message: L("devices.revoke_body"),
                                       action: L("devices.revoke")) {
            Task {
                guard await model.attempt({ try await api.delete("devices/\(device.id)") }) != nil else { return }
                model.show(L("devices.revoked"))
                await devices.load(model) { try await api.get("devices") }
            }
        }
    }
}
