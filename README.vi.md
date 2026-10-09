# QuickTab

QuickTab là ứng dụng menu bar cho macOS 14+, mô phỏng Alt-Tab của Windows bằng Option + Tab để chuyển giữa từng cửa sổ.

## Cài đặt

Tải DMG từ GitHub Releases, mở DMG rồi kéo `QuickTab.app` vào `Applications`. Mở app từ `/Applications/QuickTab.app`, sau đó cấp Accessibility trong System Settings → Privacy & Security → Accessibility. Screen Recording là quyền tùy chọn để hiển thị thumbnail.

Trong **Cài đặt**, chọn modifier và phím chuyển cửa sổ. Mặc định là Option + Tab; Shift đảo chiều và Escape hủy phiên. Nút **Khôi phục Option + Tab** đưa về mặc định.

## Build từ source

```bash
swift build
swift run QuickTabChecks
swift test
./build.sh
./package-dmg.sh
```

Command Line Tools có thể thiếu XCTest; khi đó dùng `swift run QuickTabChecks` hoặc chọn Xcode toolchain.

## Đóng góp

Đọc [CONTRIBUTING.md](CONTRIBUTING.md), [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) và [README.md](README.md). QuickTab không dùng private API; thay đổi về phím tắt, focus hoặc quyền macOS cần mô tả rõ trong PR.

## Giới hạn

macOS không đảm bảo điều khiển mọi cửa sổ fullscreen, Spaces hoặc ứng dụng không hỗ trợ Accessibility. Khi không có Screen Recording, QuickTab vẫn chuyển cửa sổ bằng icon và tiêu đề.
