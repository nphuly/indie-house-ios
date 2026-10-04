import Combine
import Foundation
import UIKit

private final class NoRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

@MainActor final class IndieAPI: ObservableObject {
    @Published private(set) var profile: InstanceManifest?
    @Published private(set) var signedIn = false
    /// Set when the server rejects the session while signed in; the app returns to sign-in with a notice.
    @Published var sessionExpired = false
    private var tokens: Tokens?
    private var verified = false
    private var refreshTask: Task<Void, Error>?
    private let images = NSCache<NSURL, UIImage>()
    private var missingImages = Set<URL>()
    private var imageTasks: [URL: Task<UIImage?, Never>] = [:]
    private let session = URLSession(configuration: .ephemeral, delegate: NoRedirects(), delegateQueue: nil)
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    /// Restores the saved library and session. The identity is checked only when there is a session to use.
    func restore() async throws {
        if let saved = UserDefaults.standard.data(forKey: "indiehouse.profile") {
            profile = try decoder.decode(InstanceManifest.self, from: saved)
            if let raw = CredentialStore.read("session.\(profile!.id)") {
                tokens = try? decoder.decode(Tokens.self, from: raw)
            }
            if tokens != nil { try await verifyIdentity() }
            signedIn = tokens != nil
        }
    }

    func discover(_ input: String) async throws -> InstanceManifest {
        let url = try InstanceManifest.manifestURL(from: input)
        let data = try await send(url: url)
        return try InstanceManifest.parse(decoder.decode(ManifestPayload.self, from: data), at: url)
    }

    func trust(_ candidate: InstanceManifest) throws {
        if let current = profile, current.origin == candidate.origin, current.id != candidate.id {
            throw IndieError.message(L("error.identity_changed"))
        }
        profile = candidate
        tokens = nil
        signedIn = false
        verified = true
        clearImages()
        UserDefaults.standard.set(try JSONEncoder().encode(candidate), forKey: "indiehouse.profile")
    }

    func verifyIdentity() async throws {
        guard let current = profile else { throw IndieError.message(L("error.connect_first")) }
        let latest = try await discover(current.origin.absoluteString)
        guard latest.id == current.id && latest.origin == current.origin else {
            verified = false
            signedIn = false
            throw IndieError.message(L("error.identity_mismatch"))
        }
        verified = true
    }

    func login(email: String, password: String) async throws {
        try await verifyIdentity()
        let data = try await send(url: try apiURL("auth/token"), method: "POST",
                                  body: ["email": email, "password": password,
                                         "device_name": UIDevice.current.model, "platform": "ios"])
        try saveTokens(decoder.decode(TokenResponse.self, from: data))
        sessionExpired = false
    }

    func redeem(code: String, name: String, email: String, password: String) async throws {
        try await verifyIdentity()
        _ = try await send(url: try apiURL("invites/redeem"), method: "POST",
                           body: ["invite_code": code, "name": name, "email": email,
                                  "password": password, "password_confirmation": password])
        try await login(email: email, password: password)
    }

    func logout() async {
        if verified, let refresh = tokens?.refreshToken {
            _ = try? await send(url: try apiURL("auth/logout"), method: "POST",
                                body: ["refresh_token": refresh])
        }
        clearTokens()
    }

    func disconnect() async {
        await logout()
        profile = nil
        verified = false
        UserDefaults.standard.removeObject(forKey: "indiehouse.profile")
    }

    func get<T: Decodable>(_ path: String, as type: T.Type = T.self) async throws -> T {
        try decoder.decode(Envelope<T>.self, from: await authorized(url: try apiURL(path))).data
    }

    func catalogue(page: Int) async throws -> CataloguePage {
        try decoder.decode(CataloguePage.self, from: await authorized(url: try apiURL("catalogue?page=\(page)")))
    }

    /// A page of `albums` or `artists`.
    func list<Item: Decodable>(_ path: String, page: Int) async throws -> ListPage<Item> {
        try decoder.decode(ListPage<Item>.self, from: await authorized(url: try apiURL("\(path)?page=\(page)")))
    }

    func search(_ term: String) async throws -> SearchResult {
        var components = URLComponents(url: try apiURL("search"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "q", value: term)]
        return try decoder.decode(Envelope<SearchResult>.self,
                                  from: await authorized(url: components.url!)).data
    }

    func post(_ path: String, body: [String: Any]) async throws {
        _ = try await authorized(url: try apiURL(path), method: "POST", body: body)
    }

    func patch(_ path: String, body: [String: Any]) async throws {
        _ = try await authorized(url: try apiURL(path), method: "PATCH", body: body)
    }

    func delete(_ path: String) async throws {
        _ = try await authorized(url: try apiURL(path), method: "DELETE")
    }

    /// Sends a request and decodes the `data` of the reply, e.g. a saved playlist.
    func send<T: Decodable>(_ method: String, _ path: String, body: [String: Any]? = nil,
                            as type: T.Type = T.self) async throws -> T {
        try decoder.decode(Envelope<T>.self, from: await authorized(url: try apiURL(path), method: method, body: body)).data
    }

    // MARK: Artwork

    /// Artwork for albums and artists known only from track data.
    func derivedArtwork(_ kind: String, id: String) -> URL? {
        guard let profile, id.range(of: "^[0-9A-Za-z-]{1,64}$", options: .regularExpression) != nil else { return nil }
        return profile.apiBase.appendingPathComponent("\(kind)/\(id)/artwork")
    }

    func cachedImage(_ url: URL?) -> UIImage? {
        guard let url else { return nil }
        return images.object(forKey: url as NSURL)
    }

    /// The terms of use or privacy policy. Public, so the invitation form can show it before sign-in.
    func legal(_ document: String) async throws -> LegalDocument {
        guard ["terms", "privacy"].contains(document) else { throw APIStatus.missing }
        return try decoder.decode(Envelope<LegalDocument>.self, from: await send(url: try apiURL("legal/\(document)"))).data
    }

    /// Loads artwork, and the account's own picture, from this library's mobile API only.
    /// Misses are remembered for the session.
    func image(_ url: URL?) async -> UIImage? {
        guard let url, isArtworkURL(url), !missingImages.contains(url) else { return nil }
        if let cached = images.object(forKey: url as NSURL) { return cached }
        if let running = imageTasks[url] { return await running.value }
        let task = Task<UIImage?, Never> { [weak self] in
            guard let self else { return nil }
            do {
                let data = try await self.authorized(url: url, accept: "image/jpeg, image/png, image/webp, image/gif")
                guard data.count <= 8_000_000, let image = UIImage(data: data) else {
                    self.missingImages.insert(url)
                    return nil
                }
                self.images.setObject(image, forKey: url as NSURL)
                return image
            } catch {
                if case APIStatus.missing = error { self.missingImages.insert(url) }
                return nil
            }
        }
        imageTasks[url] = task
        let image = await task.value
        imageTasks[url] = nil
        return image
    }

    private func isArtworkURL(_ url: URL) -> Bool {
        guard let profile, url.scheme == "https", url.host?.lowercased() == profile.origin.host?.lowercased(),
              url.port == nil || url.port == 443, url.user == nil, url.query == nil, url.fragment == nil else { return false }
        return url.path.range(of: "^/api/v1/mobile/((tracks|artists|albums)/[0-9A-Za-z-]{1,64}/artwork|account/avatar/[0-9a-f]{12})$",
                              options: .regularExpression) != nil
    }

    private func clearImages() {
        images.removeAllObjects()
        missingImages.removeAll()
    }

    struct StreamChunk {
        let data: Data
        let totalLength: Int64
        /// "audio/flac" for the lossless rendition, otherwise "audio/mpeg".
        let contentType: String
    }

    /// A non-206 answer from the stream gateway. The code decides whether trying again can help.
    struct StreamStatus: LocalizedError {
        let code: Int
        let message: String?
        var errorDescription: String? { L("error.stream_http", code, message.map { ": \($0)" } ?? "") }
    }

    /// Phones drop connections when they switch networks, and the gateway or the tunnel in
    /// front of it can briefly fail, so a chunk is tried three more times, 0.5, 1 and 2 s
    /// apart, before playback gives up.
    func streamChunk(for track: Track, quality: String, from start: Int64,
                     length: Int) async throws -> StreamChunk {
        var retries = 0
        while true {
            do {
                return try await streamChunkOnce(for: track, quality: quality, from: start, length: length)
            } catch let error where retries < 3 && Self.isTransient(error) {
                retries += 1
                try await Task.sleep(for: .milliseconds(250 << retries))
            }
        }
    }

    private static func isTransient(_ error: Error) -> Bool {
        if let status = error as? StreamStatus { return status.code >= 500 }
        guard let error = error as? URLError else { return false }
        return [.timedOut, .networkConnectionLost, .notConnectedToInternet, .cannotConnectToHost,
                .cannotFindHost, .dnsLookupFailed].contains(error.code)
    }

    private func streamChunkOnce(for track: Track, quality: String, from start: Int64,
                                 length: Int) async throws -> StreamChunk {
        guard let base = profile?.streamBase else { throw IndieError.message(L("error.not_connected")) }
        var components = URLComponents(url: base.appendingPathComponent("v1/tracks/\(track.id)/stream"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "quality", value: quality)]
        guard tokens != nil else { throw IndieError.message(L("error.login_again")) }
        if !verified { try await verifyIdentity() }
        if tokens!.expiresAt <= Date().addingTimeInterval(30) { try await refresh() }
        do {
            return try await streamRequest(components.url!, bearer: tokens!.accessToken,
                                           from: start, length: length)
        } catch APIStatus.unauthorized {
            try await refresh()
            return try await streamRequest(components.url!, bearer: tokens!.accessToken,
                                           from: start, length: length)
        }
    }

    private func streamRequest(_ url: URL, bearer: String, from start: Int64,
                               length: Int) async throws -> StreamChunk {
        let end = start + Int64(max(1, length)) - 1
        var request = URLRequest(url: url)
        // A stalled connection fails fast enough for the retry to catch up before the buffer runs out.
        request.timeoutInterval = 15
        request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        request.setValue("bytes=\(start)-\(end)", forHTTPHeaderField: "Range")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw IndieError.message(L("error.stream_no_response"))
        }
        if http.statusCode == 401 { throw APIStatus.unauthorized }
        guard http.statusCode == 206 else {
            let server = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            throw StreamStatus(code: http.statusCode,
                               message: server?["message"] as? String ?? server?["error"] as? String)
        }
        guard let range = http.value(forHTTPHeaderField: "Content-Range"),
              range.hasPrefix("bytes "),
              let bounds = range.dropFirst(6).split(separator: "/", omittingEmptySubsequences: false).first,
              let returnedStart = Int64(bounds.split(separator: "-").first ?? ""),
              let total = Int64(range.split(separator: "/").last ?? ""),
              returnedStart == start, total > 0, !data.isEmpty else {
            throw IndieError.message(L("error.stream_range"))
        }
        let contentType = http.value(forHTTPHeaderField: "Content-Type")?
            .split(separator: ";").first.map { $0.trimmingCharacters(in: .whitespaces).lowercased() } ?? "audio/mpeg"
        return StreamChunk(data: data, totalLength: total, contentType: contentType)
    }

    private func saveTokens(_ response: TokenResponse) throws {
        guard !response.accessToken.isEmpty, !response.refreshToken.isEmpty,
              response.expiresIn > 0, let id = profile?.id else {
            throw IndieError.message(L("error.session_invalid"))
        }
        let next = Tokens(accessToken: response.accessToken, refreshToken: response.refreshToken,
                          expiresAt: Date().addingTimeInterval(TimeInterval(response.expiresIn)))
        try CredentialStore.write(JSONEncoder().encode(next), for: "session.\(id)")
        tokens = next
        signedIn = true
    }

    private func clearTokens(expired: Bool = false) {
        if let id = profile?.id { CredentialStore.delete("session.\(id)") }
        if expired && signedIn { sessionExpired = true }
        tokens = nil
        signedIn = false
        clearImages()
    }

    private func refresh() async throws {
        if let current = refreshTask { return try await current.value }
        let task = Task<Void, Error> {
            guard verified, let refresh = tokens?.refreshToken else {
                throw IndieError.message(L("error.session_expired"))
            }
            do {
                let data = try await send(url: try apiURL("auth/refresh"), method: "POST",
                                          body: ["refresh_token": refresh])
                try saveTokens(decoder.decode(TokenResponse.self, from: data))
            } catch APIStatus.unauthorized {
                clearTokens(expired: true)
                throw APIStatus.unauthorized
            }
        }
        refreshTask = task
        defer { refreshTask = nil }
        try await task.value
    }

    private func authorized(url: URL, method: String = "GET", body: [String: Any]? = nil,
                            accept: String = "application/json") async throws -> Data {
        guard tokens != nil else { throw IndieError.message(L("error.login_again")) }
        if !verified { try await verifyIdentity() }
        if tokens!.expiresAt <= Date().addingTimeInterval(30) { try await refresh() }
        do {
            return try await send(url: url, method: method, body: body, bearer: tokens!.accessToken, accept: accept)
        } catch APIStatus.unauthorized {
            try await refresh()
            return try await send(url: url, method: method, body: body, bearer: tokens!.accessToken, accept: accept)
        }
    }

    private func apiURL(_ path: String) throws -> URL {
        // The library can be removed while a request is still on its way.
        guard let profile else { throw IndieError.message(L("error.not_connected")) }
        let parts = path.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        var url = profile.apiBase.appendingPathComponent(String(parts[0]))
        if parts.count == 2, var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            components.percentEncodedQuery = String(parts[1])
            url = components.url!
        }
        return url
    }

    enum APIStatus: LocalizedError {
        case unauthorized
        case missing
        var errorDescription: String? {
            switch self {
            case .unauthorized: L("error.session_bad")
            case .missing: L("error.not_found")
            }
        }
    }

    private func send(url: URL, method: String = "GET", body: [String: Any]? = nil,
                      bearer: String? = nil, accept: String = "application/json") async throws -> Data {
        guard url.scheme == "https" else { throw IndieError.message(L("error.https_required")) }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue(accept, forHTTPHeaderField: "Accept")
        // Server messages (sign-in errors, rate limits) come back in the app's language.
        request.setValue(AppLanguage.shared.code, forHTTPHeaderField: "Accept-Language")
        if let bearer { request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization") }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await session.data(for: request)
        guard let status = response as? HTTPURLResponse else { throw IndieError.message(L("error.no_response")) }
        if status.statusCode == 401 { throw APIStatus.unauthorized }
        if (300..<400).contains(status.statusCode) {
            throw IndieError.message(L("error.redirect"))
        }
        if status.statusCode == 404 { throw APIStatus.missing }
        guard (200..<300).contains(status.statusCode) else {
            let server = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let message = server?["message"] as? String ?? server?["error"] as? String
            throw IndieError.message(message ?? L("error.request_failed", status.statusCode))
        }
        return data
    }
}
