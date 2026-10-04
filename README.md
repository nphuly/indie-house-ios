# Indie House iOS

**English** · [Tiếng Việt](README.vi.md)

The native iOS client for [Indie House](https://github.com/nphuly/indie-house-server), a self-hosted, invite-only music streaming service. It is written in SwiftUI and needs iOS 17 or later.

| Repository | What |
| --- | --- |
| [indie-house-server](https://github.com/nphuly/indie-house-server) | Backend: Laravel control plane, Go media worker and stream gateway, documentation |
| **indie-house-ios** (this one) | Native iOS client in SwiftUI |
| [indie-house-android](https://github.com/nphuly/indie-house-android) | Android 4.3 (API 18) client for the BlackBerry Leap |

## Features

- Connects to any Indie House instance by its HTTPS address or by scanning the QR code from the admin panel. It reads `/.well-known/indie-house` and asks the user to confirm the instance name and hostname before connecting.
- Signs in or redeems an invite. Access and refresh tokens live in the Keychain, and the instance identity is checked again before an old session is reused.
- Home, search, catalogue, artists, albums, library, playlists (create, edit, add and remove songs), listening history, devices and settings, all through the server's [mobile API](https://github.com/nphuly/indie-house-server/blob/main/docs/en/mobile-api.md).
- Playback with `AVPlayer` and an `AVAssetResourceLoader` that streams MP3 or FLAC from the gateway with a Bearer token and HTTP `Range`, so the app never receives object-storage URLs. Background audio, Lock Screen controls, a queue, shuffle and repeat. If FLAC will not play, the player falls back to 320 kbps.
- Vietnamese (default) and English, switchable without stopping the music.
- The ["Biển hiệu" design system](https://github.com/nphuly/indie-house-server/blob/main/docs/en/design-system.md) shared with the web app and the Android client.

## Building

Open `IndieHouse.xcodeproj` in Xcode, select the `IndieHouse` target, turn on **Automatically manage signing** and choose your Team, then run on an iPhone or the Simulator. Keep the bundle identifier if you want to install over an earlier build; a different identifier makes iOS treat it as another app.

To build without signing:

```bash
xcodebuild -project IndieHouse.xcodeproj -scheme IndieHouse -configuration Debug -sdk iphoneos -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

Run the unit tests on a simulator with `xcodebuild test -project IndieHouse.xcodeproj -scheme IndieHouse -destination 'platform=iOS Simulator,name=<device>'`.

To use the app you need a running [indie-house-server](https://github.com/nphuly/indie-house-server) instance served over HTTPS.

## Project layout

The code in `IndieHouse/` is layered: `Core` has no UI, `DesignSystem` knows nothing about data or `AppModel`, `Shared` uses nothing from `Features`, and among the `Features` folders only `Shell` builds other screens (`Player` re-presents the shell's toasts, dialogs and sheets while it is full screen).

| Folder | Contents |
| --- | --- |
| `App/` | Entry point (`IndieHouseApp`); `ContentView` chooses between startup, sign-in and the app; `AppModel` holds navigation, toasts, sheets, dialogs and shared actions; `AppState` holds the related types (`Tab`, `Route`, `SheetKind`…) |
| `Core/Models` | Mobile API types: manifest, catalogue, account |
| `Core/Networking` | `IndieAPI` (requests, tokens, artwork), `CredentialStore` (Keychain), `IndieError` |
| `Core/Playback` | `MusicPlayer` (queue, shuffle, repeat, play logging) and `AuthenticatedAudioLoader` |
| `Core/Localization` | `L()`, `plural()`, `upper()` and `Format` (durations, relative times) |
| `DesignSystem/` | Colour tokens, fonts, cut corners, icons, motion; `Components/` holds data-agnostic pieces: buttons, headers, empty states, skeletons, forms, marquee |
| `Shared/` | Data-aware pieces used on several screens: artwork, `TrackRow` and the song menu, cards and shelves, tiles, detail heroes, the sheet frame, `Loader` |
| `Features/` | One folder per part of the app: `Auth`, `Shell` (tabs, pages, mini player, toasts, dialogs), `Home`, `Search`, `Browse`, `Library` (with playlists and history), `Catalogue` (albums, artists), `Settings`, `Player`, `Sheets` (song menu, add to playlist, playlist form, queue) |
| `Resources/` | `Info.plist`, the asset catalog, fonts, `LaunchScreen` and the vi/en strings |

`IndieHouse` and `IndieHouseTests` are Xcode synchronized folders: adding, renaming or moving files inside them needs no change to `project.pbxproj`. Each file holds one screen or a small group of components; `private` types stay inside their file.

## Strings and assets

- Strings live in `IndieHouse/Resources/vi.lproj` and `en.lproj/Localizable.strings` and are read through `L()` in `Core/Localization/Localization.swift`. Plurals use `.one`/`.other` keys with `plural()`. Both files must have the same keys. The chosen language is stored on the device, sent to the server as `Accept-Language`, and applied at once.
- Chakra Petch and JetBrains Mono (SIL OFL 1.1) are in `IndieHouse/Resources/Fonts`.
- Icons are vector PDFs in `Resources/Assets.xcassets/Glyphs` (not `Icons`: `.gitignore` ignores `Icon?`), together with the `ConnectHero` image. They are generated from the web's icon set by `python3 scripts/generate-legacy-android-assets.py --only ios` in [indie-house-server](https://github.com/nphuly/indie-house-server), with this repository checked out next to it as `../indie-house-ios` or `INDIE_HOUSE_IOS` pointing here. It needs `rsvg-convert` and Pillow.

## How it talks to the server

The app reads the HTTPS manifest, asks the user to confirm the name and hostname, stores a profile per `instance_id`, keeps tokens in the Keychain (`AfterFirstUnlockThisDeviceOnly`), and checks the instance identity again before reusing a session. When the access token expires, the next `Range` request refreshes it. Each audio chunk is retried up to three times on network errors; if playback still fails, tapping Play resumes the same track. HLS is not used: its playlists and segments would each need the Bearer token, and `AVURLAssetHTTPHeaderFieldsKey` is not public API.

## Status

The app builds and its unit tests pass on the Simulator. The connection and sign-in screens have been reviewed on the Simulator; the screens after sign-in only with sample data. Before handing it to users, test on a real iPhone: QR permission, sign-in and token refresh, artwork, playing and seeking over Wi-Fi and mobile data, background audio, playlists, and switching networks while playing.

## License

[PolyForm Noncommercial License 1.0.0](LICENSE): noncommercial use only. See also [DISCLAIMER.md](DISCLAIMER.md).
