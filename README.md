# QuickTab

Ứng dụng menu bar cho macOS 14+, chuyển **từng cửa sổ** bằng Option + Tab. SwiftUI + AppKit, Accessibility, CGEventTap và ScreenCaptureKit; build bằng Swift Package Manager, không cần tạo project trong Xcode.

## Chạy từ VS Code

Cài Command Line Tools nếu chưa có:

```bash
xcode-select --install
swift --version
xcrun --show-sdk-path
```

Cần Swift 5.9+ và macOS SDK 14+. Mở thư mục này trong VS Code, cài [Swift chính thức](https://code.visualstudio.com/docs/languages/swift) (`swiftlang.swift-vscode`); cài CodeLLDB (`vadimcn.vscode-lldb`) nếu dùng cấu hình debug đã cung cấp.

```bash
chmod +x build.sh run.sh
./build.sh
./run.sh
```

Ứng dụng ở `dist/QuickTab.app`, biểu tượng hai cửa sổ trên menu bar. Lần đầu mở có hướng dẫn quyền. `run.sh` luôn chạy build tăng dần rồi mở bundle; nếu QuickTab đã chạy, hãy chọn **Thoát QuickTab** trước khi chạy lại để sử dụng executable mới. Không chạy nhiều bản sao ở các đường dẫn khác nhau.

Các lệnh riêng:

```bash
swift build
swift run QuickTabChecks
swift test
CONFIGURATION=release ./build.sh
```

`swift build` chỉ tạo executable; nên dùng bundle để cấp quyền. `swift test` cần toolchain có XCTest. Command Line Tools trên máy kiểm tra không có XCTest: dùng `swift run QuickTabChecks` để chạy kiểm tra logic không dependency, hoặc cài Xcode chỉ để cung cấp SDK/test framework:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Không cần tạo project hay viết code trong giao diện Xcode. Nếu compiler báo SDK/toolchain không khớp, kiểm tra `xcode-select -p`, `swift --version`, `xcrun --show-sdk-path` và chọn cùng một bộ công cụ.

## Cách dùng

| Thao tác | Kết quả |
| --- | --- |
| Giữ Option và nhấn Tab | Mở switcher, chọn cửa sổ trước đó |
| Tiếp tục Tab / giữ Tab | Tiến một cửa sổ / lặp theo key repeat của macOS |
| Option + Shift + Tab | Lùi một cửa sổ |
| Nhả phím Option cuối cùng | Chuyển đến cửa sổ đã chọn |
| Escape | Hủy, không chủ động đổi focus |

Chọn **Cài đặt…** trên menu bar để bật/tắt, đổi modifier và phím chuyển cửa sổ, điều chỉnh card, giới hạn danh sách (1–100), thumbnail, animation (0 để tắt) và Launch at Login. QuickTab cũng tôn trọng Reduce Motion. Mặc định: Option + Tab, bật QuickTab/thumbnail, card 240 pt, tối đa 30 cửa sổ, animation 100 ms; Launch at Login chỉ đăng ký khi bạn bật. Shift vẫn đảo chiều, Escape vẫn hủy phiên.

## Quyền truy cập

- **Accessibility:** bắt buộc để liệt kê, điều khiển cửa sổ và sử dụng event tap lọc phím. Trong Cài đặt của QuickTab, chọn **Cấp quyền**, bật đúng `dist/QuickTab.app` tại System Settings → Privacy & Security → Accessibility. Dùng nút `+` nếu ứng dụng chưa xuất hiện.
- **Screen Recording:** tùy chọn, dùng để lấy thumbnail. Từ chối vẫn dùng icon/title và chuyển cửa sổ bình thường. Chỉ yêu cầu quyền khi bấm nút, không hỏi lại tự động. macOS có thể yêu cầu thoát rồi mở lại ứng dụng sau khi thay đổi quyền.
- **Input Monitoring:** QuickTab dùng active session event tap, không phải listener thụ động. Accessibility và việc tạo/enable tap thực tế quyết định khả năng hoạt động. Nếu tap thất bại dù đã cấp Accessibility, giao diện hiện trạng thái Input Monitoring và nút mở phần quyền đó; không bắt buộc người dùng cấp mọi quyền trước khi thử tap.

Trạng thái được kiểm tra khi ứng dụng được kích hoạt, khi chuyển ứng dụng và mỗi 2 giây trong lúc cửa sổ Settings mở. Overlay kiểm tra mất quyền/mất modifier mỗi 250 ms **chỉ khi đang hiển thị**; không quét toàn bộ cửa sổ định kỳ khi idle. Khi event tap mất đồng bộ, phiên được hủy để tránh chuyển nhầm cửa sổ.

Chẩn đoán không yêu cầu quyền và không cài event tap:

```bash
dist/QuickTab.app/Contents/MacOS/QuickTab --diagnostics
```

Chẩn đoán khi chạy executable trực tiếp có thể được TCC quy thuộc khác với khi Launch Services mở bundle. Kiểm tra trạng thái trong Settings của ứng dụng đang chạy là bước xác nhận cuối cùng.

## Code signing

Bundle identifier luôn là `com.local.quicktab`, bundle luôn ở `dist/QuickTab.app`. Script mặc định ad-hoc sign; không thêm entitlement App Sandbox, không đổi bundle ID và không sửa cơ sở dữ liệu TCC.

Nếu có chứng chỉ Apple Development trong Keychain:

```bash
security find-identity -v -p codesigning
export SIGNING_IDENTITY='Apple Development: Your Name (TEAMID)'
./build.sh
./run.sh
```

Giữ cùng chứng chỉ, bundle ID và đường dẫn giữa các lần build. Nếu identity được chỉ định sai, script dừng và **không** tự chuyển sang ad-hoc. Ad-hoc signature thay đổi theo nội dung executable; macOS có thể yêu cầu cấp lại Accessibility sau rebuild. Ngay cả với chứng chỉ ổn định, hệ điều hành vẫn có thể yêu cầu cấp lại quyền.

Nếu quyền không có hiệu lực: thoát QuickTab, xác nhận chỉ còn một bundle được sử dụng, xóa entry cũ của QuickTab trong phần quyền tương ứng và thêm lại bundle hiện tại. Script không tự reset quyền.

Bản này phục vụ chạy local. Phân phối ngoài máy phát triển cần quy trình riêng: Developer ID Application, cấu hình hardened runtime phù hợp, notarization/stapling và kiểm tra trên máy sạch; không dùng bản ad-hoc như một bản phát hành đã notarize.

## Tạo bộ cài DMG

Tạo bản release dạng kéo-thả vào Applications:

```bash
chmod +x build.sh package-dmg.sh
./package-dmg.sh
```

File kết quả là `dist/QuickTab-1.0.0.dmg`. Có thể đổi phiên bản:

```bash
VERSION=1.1.0 ./package-dmg.sh
```

Mở DMG, kéo `QuickTab.app` vào thư mục `Applications`, sau đó mở `/Applications/QuickTab.app`. Gỡ cài đặt bằng cách thoát QuickTab rồi đưa `/Applications/QuickTab.app` vào Trash. Cài đặt và quyền Accessibility/Screen Recording thuộc từng máy; DMG không mang theo quyền từ máy build.

Bản không có `SIGNING_IDENTITY` dùng ad-hoc signing và chỉ nên gửi cho máy cá nhân/nội bộ. Bản phát hành công khai cần Developer ID, hardened runtime, notarization và staple ticket trước khi gửi DMG:

```bash
export SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)'
./package-dmg.sh
xcrun notarytool submit dist/QuickTab-1.0.0.dmg --apple-id 'email@example.com' --team-id 'TEAMID' --password 'APP_SPECIFIC_PASSWORD' --wait
xcrun stapler staple dist/QuickTab.app
```

Sau khi staple, cần tạo lại DMG rồi kiểm tra lại trước khi phát hành. `package-dmg.sh` kiểm tra `hdiutil verify`, chữ ký app, `Info.plist`, bundle identifier, `QuickTab.app` và alias `Applications` bên trong DMG.

Launch at Login dùng [SMAppService.mainApp](https://developer.apple.com/documentation/servicemanagement/smappservice/mainapp). Giữ nguyên vị trí bundle sau khi bật. Nếu hệ thống yêu cầu phê duyệt, Settings hiển thị nút đến Login Items; lỗi đăng ký được hiển thị, không giả định đã thành công. Sau khi thay executable/di chuyển app, có thể cần tắt/bật lại đăng ký.

## Cấu trúc và luồng dữ liệu

```text
Package.swift
Sources/
  QuickTabCore/          State machine phím, định danh, MRU, selection, preview matcher, cache
  QuickTab/              AppKit lifecycle, SwiftUI views, services, controller
  QuickTabChecks/        Kiểm tra logic chạy được với Command Line Tools
Tests/QuickTabCoreTests/ XCTest cho toolchain có test framework
Resources/              Info.plist, entitlements
.vscode/                Tasks, LLDB launch/attach, extensions
build.sh, run.sh
```

- Event tap có thread/run loop riêng, một instance. Callback không quét AX/chụp ảnh; gửi lệnh theo thứ tự lên main queue. State machine giữ trạng thái consumed key-down/up, key repeat và cả hai phím Option.
- AX registry và truy vấn chạy trên serial queue riêng, timeout 150 ms cho mỗi message. NSWorkspace/AX notifications kích hoạt refresh có gộp sự kiện; mở switcher cũng yêu cầu refresh. Ứng dụng tạm thời không phản hồi giữ dữ liệu cũ thay vì xóa MRU.
- `WindowID` gồm PID, generation của lần chạy ứng dụng và serial nội bộ. Registry so sánh AX elements bằng `CFEqual`; title thay đổi không thay identity. MRU chỉ theo focus thật và sống trong phiên chạy QuickTab.
- Trong overlay, thứ tự đóng băng: cửa sổ đóng được loại, cửa sổ mới thêm cuối trong giới hạn cấu hình. Lần đầu chưa có snapshot giữ lệnh Tab/nhả Option trong lúc tải, với thời hạn 1,5 giây để hủy nếu chưa có dữ liệu.
- Kích hoạt kiểm tra generation/AX reference còn hợp lệ, unhide/unminimize, activate, raise đúng element rồi xác nhận focus; thử raise thêm một lần nếu ứng dụng phản hồi trễ. Không chọn một cửa sổ cùng app chỉ vì cửa sổ mục tiêu đã đóng.
- SwiftUI models/services UI dùng MainActor. NSPanel không kích hoạt ứng dụng, hỗ trợ fullscreen auxiliary. Màn hình được chọn theo vị trí cửa sổ active, fallback con trỏ; bố cục giới hạn trong visible frame.
- Thumbnail dùng [SCScreenshotManager](https://developer.apple.com/documentation/screencapturekit/scscreenshotmanager), tối đa hai capture đang chờ hoàn thành, cạnh dài tối đa 640 pixel. Cache LRU giới hạn 64 MiB; ảnh đủ mới được tái sử dụng. Không stream liên tục; nội dung preview có thể cũ trong lúc giữ overlay lâu.
- Liên kết AX ↔ SCWindow bằng PID, geometry và title có kiểm tra mơ hồ. Không dùng `_AXUIElementGetWindow`, `AXWindowNumber` hay API riêng. Không ghép chắc được thì dùng placeholder. Kết quả thuộc phiên đã đóng bị loại; slot capture chỉ trả lại khi lời gọi native thật sự kết thúc.

## VS Code và debug

Run Task có: **Swift Build**, **Build macOS App**, **Run QuickTab**, **Clean Build**, **Core Checks**, **Unit Tests (Xcode toolchain)**. Clean Build chỉ dọn cache SwiftPM, giữ bundle đã cấp quyền.

F5 → **Debug QuickTab.app** để launch executable bên trong bundle. Nếu debugger làm thay đổi cách TCC nhận diện tiến trình, mở bằng `./run.sh` trước rồi dùng **Attach QuickTab**. Thoát instance cũ trước khi debug instance mới. Lỗi runtime được ghi bằng `NSLog` và hiển thị trong Settings/menu tooltip.

```bash
log stream --predicate 'process == "QuickTab"' --level info
```

## Kiểm thử giao diện và tương tác

Render UI với **dữ liệu mẫu**, không yêu cầu quyền chụp màn hình hoặc phát sự kiện bàn phím:

```bash
dist/QuickTab.app/Contents/MacOS/QuickTab --render-ui dist/ui-check
```

Lệnh tạo `switcher.png` và `settings.png` bằng render view của chính ứng dụng. Nó xác minh layout/khởi tạo view, không xác minh native blur phía sau màn hình, ScreenCaptureKit hay chuyển focus ứng dụng khác.

Checklist thử thủ công sau khi cấp quyền:

1. Mở ít nhất hai cửa sổ Finder/Terminal/Chrome. Chuyển từng cửa sổ, kiểm tra đúng title và focus.
2. Chuyển A → B → Option+Tab phải chọn A; đổi title không thay thứ tự MRU.
3. Giữ Tab để repeat; thử Shift+Tab, hai phím Option, nhả Option thật nhanh; không có Tab lọt vào trình soạn thảo.
4. Escape không đưa cửa sổ đang chọn ra trước. Tắt QuickTab trong menu thì Option+Tab đi qua bình thường.
5. Minimize cửa sổ, hide ứng dụng, đóng cửa sổ đang chọn, quit/crash app; không crash hoặc chuyển sang cửa sổ khác do trùng PID.
6. Từ chối/thu hồi Screen Recording: icon/title vẫn dùng được. Thu hồi Accessibility: hủy overlay và báo trạng thái, không giữ phím.
7. Thử nhiều Spaces, fullscreen, màn hình ngoài, đổi độ phân giải/ngắt màn hình; lựa chọn vẫn nằm trong overlay.
8. Bật/tắt Launch at Login và xác nhận trạng thái trong System Settings; chỉ đăng xuất/đăng nhập khi bạn chủ động muốn thử.
9. Dùng Activity Monitor kiểm tra CPU lúc idle và RAM sau nhiều lần mở/đóng switcher.

## Giới hạn

- API công khai không bảo đảm chuyển Spaces/fullscreen, focus hoặc enumerate mọi cửa sổ của mọi ứng dụng. Cửa sổ không cung cấp AX role/subrole/geometry phù hợp sẽ bị bỏ qua.
- Chỉ lấy cửa sổ chuẩn/dialog của ứng dụng có activation policy regular; loại desktop, tooltip, menu và QuickTab. Một số utility/panel đặc thù không nằm trong danh sách.
- Minimized/hidden/offscreen/protected windows có thể không capture được: dùng ảnh cache hợp lệ hoặc icon. Ghép preview không chắc chắn sẽ không hiển thị ảnh.
- Ứng dụng không phát đủ AX notifications có thể cập nhật title/list/MRU chậm đến lần refresh sau; không giả định đọc được toàn bộ lịch sử trước khi QuickTab khởi động.
- Secure Input, màn hình khóa hoặc cơ chế bảo mật hệ thống có thể làm shortcut không hoạt động. QuickTab không vượt qua các cơ chế này.
- `Command + Tab` là App Switcher của macOS và có thể bị hệ thống chiếm trước khi QuickTab nhận được sự kiện. Settings sẽ cảnh báo và đề xuất `Control + Tab`, `Option + Tab` hoặc `Command + Return`.
- Không có installer, cập nhật tự động hoặc notarization trong phạm vi bản local.

Xem `VALIDATION.md` để biết các kiểm tra thực sự đã chạy và các mục còn cần thử trực tiếp.

## Open-source project

QuickTab is MIT-licensed and welcomes focused pull requests. See [CONTRIBUTING.md](CONTRIBUTING.md), [SECURITY.md](SECURITY.md), [CHANGELOG.md](CHANGELOG.md), and the [development docs](docs/DEVELOPMENT.md). The Vietnamese guide is available in [README.vi.md](README.vi.md).

The app bundle includes the QuickTab two-window blue icon (`Resources/AppIcon.icns`), so no separate icon installation is needed. The menu bar uses the same asset as a monochrome template.

GitHub Actions validates pull requests and `main`. A `vX.Y.Z` tag builds a DMG and publishes it with a SHA-256 checksum. CI cannot grant macOS TCC permissions, so global keyboard and real window activation still require manual testing on a permitted machine.
