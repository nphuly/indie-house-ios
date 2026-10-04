import XCTest
@testable import IndieHouse

class IndieHouseTests: XCTestCase {

  func testRejectsUntrustedManifestURL() {
    XCTAssertThrowsError(try InstanceManifest.manifestURL(from: "http://example.com"))
    XCTAssertThrowsError(try InstanceManifest.manifestURL(from: "https://example.com.evil.test/path"))
  }

  func testRejectsManifestWithDifferentStreamOrigin() throws {
    let manifestURL = try InstanceManifest.manifestURL(from: "https://example.com")
    let payload = ManifestPayload(schemaVersion: 1, instanceId: UUID().uuidString,
        displayName: "Indie House", apiBase: URL(string: "https://example.com/api/v1/mobile")!,
        streamBase: URL(string: "https://elsewhere.test/api/v1/stream")!,
        jwtIssuer: URL(string: "https://example.com")!,
        registrationMode: "invite_only", minimumMobileVersion: "1.0.0")
    XCTAssertThrowsError(try InstanceManifest.parse(payload, at: manifestURL)) { error in
      XCTAssertTrue(error.localizedDescription.contains("stream_base=https://elsewhere.test/api/v1/stream"))
    }
  }

  func testAcceptsCurrentInstanceManifest() throws {
    let manifestURL = try InstanceManifest.manifestURL(from: "https://example.com")
    let id = UUID().uuidString
    let payload = ManifestPayload(schemaVersion: 1, instanceId: id,
        displayName: "Indie House", apiBase: URL(string: "https://example.com/api/v1/mobile")!,
        streamBase: URL(string: "https://example.com/api/v1/stream")!,
        jwtIssuer: URL(string: "https://example.com")!,
        registrationMode: "invite_only", minimumMobileVersion: "1.0.0")
    XCTAssertEqual(try InstanceManifest.parse(payload, at: manifestURL).id, id)
    XCTAssertEqual(try InstanceManifest.manifestURL(from: "https://example.com:443").absoluteString,
                   manifestURL.absoluteString)
    XCTAssertNil(Version("1.0.0."))
  }

  func testDeviceResponseUsesUUIDSessionIDs() throws {
    let json = Data(#"{"data":[{"id":"9bb496ce-e9c4-4072-88c6-349dfb70f1fd","device_name":"iPhone","platform":"ios"}]}"#.utf8)
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    let devices = try decoder.decode(Envelope<[MobileDevice]>.self, from: json).data
    XCTAssertEqual(devices.first?.id, "9bb496ce-e9c4-4072-88c6-349dfb70f1fd")
  }

  func testRecentlyPlayedShowsEachTrackOnceInLatestOrder() {
    func track(_ id: String) -> Track {
      Track(id: id, title: id, durationSeconds: nil, genre: nil,
            artist: nil, albums: nil, artworkUrl: nil, streamPath: nil)
    }
    let history = ["a", "b", "a", "c", "b"].map { PlayHistory(track: track($0), createdAt: nil) }
    let library = LibraryData(playlists: [], history: history)
    XCTAssertEqual(library.recentTracks.map(\.id), ["a", "b", "c"])
  }

  func testSearchArtistDecodesAvatarEndpoint() throws {
    let json = Data(#"{"data":{"tracks":[],"artists":[{"id":"artist123","name":"Indie Artist","avatar_url":"https://example.com/api/v1/mobile/artists/artist123/artwork"}],"albums":[]}}"#.utf8)
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    let result = try decoder.decode(Envelope<SearchResult>.self, from: json).data
    XCTAssertEqual(result.artists.first?.avatarUrl?.path,
                   "/api/v1/mobile/artists/artist123/artwork")
  }

  func testAccountDecodesTheAvatarEndpoint() throws {
    let json = Data(#"{"data":{"name":"Ly","email":"ly@example.test","avatar_url":"https://example.com/api/v1/mobile/account/avatar/0123456789ab"}}"#.utf8)
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    let account = try decoder.decode(Envelope<AccountProfile>.self, from: json).data
    XCTAssertEqual(account.avatarUrl?.path, "/api/v1/mobile/account/avatar/0123456789ab")
    let none = Data(#"{"data":{"name":"Ly","email":"ly@example.test","avatar_url":null}}"#.utf8)
    XCTAssertNil(try decoder.decode(Envelope<AccountProfile>.self, from: none).data.avatarUrl)
  }

  func testLegalDocumentDecodesUnlabelledItemsAndMissingEmail() throws {
    let json = Data(#"""
    {"data":{"document":"privacy","title":"Privacy policy","updated":"Last updated: 30 September 2026",
      "intro":"Intro","sections":[{"title":"What is stored","paragraphs":[],
      "items":[{"label":"Account","text":"name"},{"label":null,"text":"plain"}]}],
      "contact":{"title":"Contact","text":"Ask the operator.","email":null},"url":"https://example.com/privacy"}}
    """#.utf8)
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    let document = try decoder.decode(Envelope<LegalDocument>.self, from: json).data
    XCTAssertEqual(document.sections.first?.items.map(\.label), ["Account", nil])
    XCTAssertNil(document.contact.email)
  }

  func testBrowseAndListPagesDecode() throws {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    let browse = Data(#"""
    {"data":{"counts":{"tracks":3,"albums":1,"artists":1},
      "new_tracks":[{"id":"track1","title":"Mưa Đêm","duration_seconds":192,"genre":null,"artist":{"id":"artist1","name":"Bến Xưa"},
        "albums":[],"artwork_url":"https://example.com/api/v1/mobile/tracks/track1/artwork","stream_path":"/s"}],
      "albums":[{"id":"album1","title":"Bến Cũ","artwork_url":null,"artist":{"id":"artist1","name":"Bến Xưa"},"track_count":1}],
      "artists":[{"id":"artist1","name":"Bến Xưa","avatar_url":null,"artwork_url":null,"track_count":1}]}}
    """#.utf8)
    let data = try decoder.decode(Envelope<BrowseData>.self, from: browse).data
    XCTAssertEqual(data.counts.albums, 1)
    XCTAssertEqual(data.newTracks.first?.title, "Mưa Đêm")
    XCTAssertEqual(data.albums.first?.trackCount, 1)
    XCTAssertEqual(data.artists.first?.name, "Bến Xưa")

    let page = Data(#"{"data":[{"id":"artist1","name":"Bến Xưa","avatar_url":null,"artwork_url":null,"track_count":2}],"meta":{"current_page":1,"last_page":3,"total":50}}"#.utf8)
    let artists = try decoder.decode(ListPage<Artist>.self, from: page)
    XCTAssertEqual(artists.data.first?.trackCount, 2)
    XCTAssertEqual(artists.meta?.lastPage, 3)
  }
}
