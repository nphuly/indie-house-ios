import Foundation

struct InstanceManifest: Codable, Equatable {
    let id: String
    let name: String
    let origin: URL
    let registrationMode: String

    var apiBase: URL { origin.appendingPathComponent("api/v1/mobile") }
    var streamBase: URL { origin.appendingPathComponent("api/v1/stream") }

    static func manifestURL(from input: String) throws -> URL {
        guard let url = URL(string: input.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme == "https", url.host != nil, url.user == nil, url.password == nil,
              url.query == nil, url.fragment == nil, url.port == nil || url.port == 443,
              ["", "/", "/.well-known/indie-house"].contains(url.path) else {
            throw IndieError.message(L("error.manifest_address"))
        }
        var parts = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        if parts.port == 443 { parts.port = nil }
        parts.path = "/.well-known/indie-house"
        return parts.url!
    }

    static func parse(_ payload: ManifestPayload, at manifestURL: URL) throws -> InstanceManifest {
        let origin = URL(string: "https://\(manifestURL.host!)\(manifestURL.port.map { ":\($0)" } ?? "")")!
        guard payload.schemaVersion == 1,
              UUID(uuidString: payload.instanceId) != nil,
              !payload.displayName.trimmingCharacters(in: .whitespaces).isEmpty,
              ["closed", "invite_only", "open"].contains(payload.registrationMode) else {
            throw IndieError.message(L("error.manifest_invalid"))
        }
        guard payload.apiBase == origin.appendingPathComponent("api/v1/mobile"),
              payload.streamBase == origin.appendingPathComponent("api/v1/stream"),
              payload.jwtIssuer == origin else {
            var mismatches: [String] = []
            if payload.apiBase != origin.appendingPathComponent("api/v1/mobile") {
                mismatches.append("api_base=\(payload.apiBase.absoluteString)")
            }
            if payload.streamBase != origin.appendingPathComponent("api/v1/stream") {
                mismatches.append("stream_base=\(payload.streamBase.absoluteString)")
            }
            if payload.jwtIssuer != origin {
                mismatches.append("jwt_issuer=\(payload.jwtIssuer.absoluteString)")
            }
            throw IndieError.message(L("error.manifest_mismatch", origin.host ?? origin.absoluteString,
                                       mismatches.joined(separator: ", ")))
        }
        guard let minimum = Version(payload.minimumMobileVersion) else {
            throw IndieError.message(L("error.manifest_version"))
        }
        guard minimum <= Version(1, 0, 0) else {
            throw IndieError.message(L("error.app_too_old", payload.minimumMobileVersion))
        }
        return InstanceManifest(id: payload.instanceId, name: payload.displayName,
                                origin: origin, registrationMode: payload.registrationMode)
    }
}

struct ManifestPayload: Decodable {
    let schemaVersion: Int
    let instanceId: String
    let displayName: String
    let apiBase: URL
    let streamBase: URL
    let jwtIssuer: URL
    let registrationMode: String
    let minimumMobileVersion: String
}

struct Version: Comparable {
    let parts: [Int]
    init(_ major: Int, _ minor: Int, _ patch: Int) { parts = [major, minor, patch] }
    init?(_ text: String) {
        let components = text.split(separator: ".", omittingEmptySubsequences: false)
        let values = components.compactMap { Int($0) }
        guard components.count == 3, values.count == 3,
              components.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }) else { return nil }
        parts = values
    }
    static func < (lhs: Version, rhs: Version) -> Bool { lhs.parts.lexicographicallyPrecedes(rhs.parts) }
}
