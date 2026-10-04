# Indie House iOS

[English](README.md) · **Tiếng Việt**

App iOS native cho [Indie House](https://github.com/nphuly/indie-house-server), dịch vụ nghe nhạc tự host chỉ dành cho người được mời. App viết bằng SwiftUI, yêu cầu iOS 17 trở lên.

| Repo | Nội dung |
| --- | --- |
| [indie-house-server](https://github.com/nphuly/indie-house-server) | Backend: control plane Laravel, media worker và stream gateway viết bằng Go, tài liệu |
| **indie-house-ios** (repo này) | App iOS native viết bằng SwiftUI |
| [indie-house-android](https://github.com/nphuly/indie-house-android) | App Android 4.3 (API 18) cho BlackBerry Leap |

## Tính năng

- Kết nối với bất kỳ instance Indie House nào bằng địa chỉ HTTPS hoặc quét mã QR trong trang quản trị. App đọc `/.well-known/indie-house` và yêu cầu người dùng xác nhận tên instance và hostname trước khi kết nối.
- Đăng nhập hoặc nhận lời mời. Access token và refresh token nằm trong Keychain, và danh tính instance được kiểm tra lại trước khi dùng lại phiên cũ.
- Trang chủ, tìm kiếm, catalogue, nghệ sĩ, album, thư viện, playlist (tạo, sửa, thêm và bỏ bài), lịch sử nghe, thiết bị và cài đặt, tất cả qua [mobile API](https://github.com/nphuly/indie-house-server/blob/main/docs/vi/mobile-api.md) của server.
- Phát nhạc bằng `AVPlayer` cùng một `AVAssetResourceLoader` lấy MP3 hoặc FLAC từ gateway với Bearer token và HTTP `Range`, nên app không bao giờ nhận URL của object storage. Có background audio, điều khiển trên Lock Screen, hàng đợi, phát ngẫu nhiên và lặp lại. Nếu không phát được FLAC, app chuyển xuống 320 kbps.
- Tiếng Việt (mặc định) và tiếng Anh, đổi được mà không dừng nhạc.
- [Hệ thiết kế "Biển hiệu"](https://github.com/nphuly/indie-house-server/blob/main/docs/vi/design-system.md) dùng chung với web và app Android.

## Build

Mở `IndieHouse.xcodeproj` bằng Xcode, chọn target `IndieHouse`, bật **Automatically manage signing** và chọn Team, rồi chạy trên iPhone hoặc Simulator. Giữ nguyên bundle identifier nếu muốn cài đè bản cũ; đổi identifier thì iOS coi đây là một app khác.

Build không ký:

```bash
xcodebuild -project IndieHouse.xcodeproj -scheme IndieHouse -configuration Debug -sdk iphoneos -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

Chạy unit test trên simulator bằng `xcodebuild test -project IndieHouse.xcodeproj -scheme IndieHouse -destination 'platform=iOS Simulator,name=<thiết-bị>'`.

Để dùng app, bạn cần một instance [indie-house-server](https://github.com/nphuly/indie-house-server) đang chạy qua HTTPS.

## Cấu trúc mã

Mã trong `IndieHouse/` chia theo lớp: `Core` không có giao diện, `DesignSystem` không biết gì về dữ liệu hay `AppModel`, `Shared` không dùng gì trong `Features`, và giữa các thư mục trong `Features` chỉ có `Shell` dựng các màn khác (`Player` hiện lại toast, hộp thoại và sheet của `Shell` khi đang mở toàn màn hình).

| Thư mục | Nội dung |
| --- | --- |
| `App/` | Điểm vào (`IndieHouseApp`); `ContentView` chọn giữa khởi động, đăng nhập và app; `AppModel` giữ điều hướng, toast, sheet, hộp thoại và các thao tác dùng chung; `AppState` là các kiểu đi kèm (`Tab`, `Route`, `SheetKind`…) |
| `Core/Models` | Kiểu dữ liệu của Mobile API: manifest, catalogue, tài khoản |
| `Core/Networking` | `IndieAPI` (request, token, artwork), `CredentialStore` (Keychain), `IndieError` |
| `Core/Playback` | `MusicPlayer` (hàng đợi, phát ngẫu nhiên, lặp lại, ghi lượt nghe) và `AuthenticatedAudioLoader` |
| `Core/Localization` | `L()`, `plural()`, `upper()` và `Format` (thời lượng, thời gian tương đối) |
| `DesignSystem/` | Token màu, font, góc vát, icon, chuyển động; `Components/` là thành phần không biết gì về dữ liệu: nút, tiêu đề, empty state, skeleton, form, marquee |
| `Shared/` | Thành phần dùng dữ liệu, dùng ở nhiều màn: artwork, `TrackRow` và menu bài hát, card và kệ, tile, hero trang chi tiết, khung sheet, `Loader` |
| `Features/` | Mỗi thư mục một phần của app: `Auth`, `Shell` (tab, trang, mini player, toast, hộp thoại), `Home`, `Search`, `Browse`, `Library` (kèm playlist và lịch sử), `Catalogue` (album, nghệ sĩ), `Settings`, `Player`, `Sheets` (menu bài hát, thêm vào playlist, form playlist, hàng đợi) |
| `Resources/` | `Info.plist`, asset catalog, font, `LaunchScreen` và chuỗi vi/en |

`IndieHouse` và `IndieHouseTests` là thư mục đồng bộ của Xcode: thêm, đổi tên hay chuyển file trong đó không cần sửa `project.pbxproj`. Mỗi file chứa một màn hình hoặc một nhóm thành phần nhỏ; kiểu `private` chỉ dùng trong file của nó.

## Chuỗi và asset

- Chuỗi nằm trong `IndieHouse/Resources/vi.lproj` và `en.lproj/Localizable.strings`, đọc qua `L()` trong `Core/Localization/Localization.swift`. Số nhiều dùng khoá `.one`/`.other` với `plural()`. Hai file phải có cùng khoá. Ngôn ngữ đã chọn lưu trên máy, được gửi lên server qua `Accept-Language`, và áp dụng ngay.
- Font Chakra Petch và JetBrains Mono (SIL OFL 1.1) nằm trong `IndieHouse/Resources/Fonts`.
- Icon là PDF vector trong `Resources/Assets.xcassets/Glyphs` (không đặt tên `Icons`: `.gitignore` bỏ qua `Icon?`), cùng ảnh `ConnectHero`. Chúng được sinh từ bộ icon của web bằng `python3 scripts/generate-legacy-android-assets.py --only ios` trong repo [indie-house-server](https://github.com/nphuly/indie-house-server), với repo này nằm cạnh ở `../indie-house-ios` hoặc biến `INDIE_HOUSE_IOS` trỏ tới đây. Cần `rsvg-convert` và Pillow.

## Cách app làm việc với server

App đọc manifest HTTPS, yêu cầu người dùng xác nhận tên và hostname, lưu profile theo `instance_id`, giữ token trong Keychain (`AfterFirstUnlockThisDeviceOnly`), và kiểm tra lại danh tính instance trước khi dùng lại phiên. Khi access token hết hạn, request `Range` tiếp theo sẽ làm mới token. Mỗi đoạn audio được thử lại tối đa ba lần khi lỗi mạng; nếu vẫn không phát được, chạm Play để phát tiếp chính bài đó. App không dùng HLS: playlist và từng segment đều cần Bearer token, còn `AVURLAssetHTTPHeaderFieldsKey` không phải API công khai.

## Trạng thái

App build được và unit test chạy qua trên Simulator. Màn kết nối và đăng nhập đã được xem trên Simulator; các màn sau đăng nhập mới chỉ xem với dữ liệu mẫu. Trước khi đưa cho người dùng, hãy thử trên iPhone thật: quyền camera cho QR, đăng nhập và làm mới token, artwork, phát và tua qua Wi-Fi lẫn mạng di động, background audio, playlist, và đổi mạng khi đang phát.

## Giấy phép

[PolyForm Noncommercial License 1.0.0](LICENSE): chỉ dùng cho mục đích phi thương mại. Xem thêm [DISCLAIMER.md](DISCLAIMER.md#tiếng-việt).
