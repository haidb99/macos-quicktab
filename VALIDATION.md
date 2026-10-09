# Kiểm tra triển khai QuickTab

Môi trường thực tế: macOS 15.5 (24F74), Apple Silicon arm64, Swift 6.1.2, Command Line Tools và SDK 15.5. Package dùng Swift tools 5.9, deployment target macOS 14.

## Đã chạy

| Kiểm tra | Kết quả |
| --- | --- |
| `swift build` | Thành công sau MVP và sau các thay đổi cuối; không còn compiler warnings/errors ở build cuối |
| `swift run QuickTabChecks` | **22/22** kiểm tra logic chạy qua |
| `swift test` | Đã chạy; không thực thi được XCTest vì toolchain báo `no such module 'XCTest'` |
| `./build.sh` | Thành công; tạo `dist/QuickTab.app` |
| `./run.sh` | Thành công; Launch Services khởi chạy app, xác nhận tiến trình đang chạy bằng `pgrep` |
| `plutil -lint` | Info.plist hợp lệ |
| Bundle metadata | `com.local.quicktab`, `LSUIElement=true`, minimum macOS 14.0 |
| `codesign --verify --strict --verbose=2` | Hợp lệ; chữ ký **ad-hoc**, không có TeamIdentifier |
| `xcrun vtool -show-build` | Mach-O arm64, minimum OS 14.0, SDK 15.5 |
| VS Code JSON / shell syntax | JSON parse thành công; `bash -n build.sh run.sh` không lỗi |
| `--render-ui dist/ui-check` | Render và xem trực tiếp ảnh overlay/Settings; đã sửa appearance của Settings và render lại |
| `--diagnostics` | Bundle đúng ID/đường dẫn; Accessibility, Screen Recording, Input Monitoring đều `false` tại thời điểm kiểm tra |

Ảnh kiểm tra dùng **dữ liệu mẫu**, được render từ view của chính ứng dụng: `dist/ui-check/switcher.png` (1600×1140) và `dist/ui-check/settings.png` (1200×1600). Chúng không phải ảnh chụp một phiên chuyển cửa sổ thật.

22 kiểm tra độc lập gồm: chuỗi nhấn/nhả nhanh, key repeat, đảo chiều, Escape, hai phím Option, khôi phục sau mất tap/modifier, không để key-up đã tiêu thụ lọt qua khi tắt, MRU hai cửa sổ, identity/PID generation, thứ tự đóng băng, cửa sổ thêm/đóng, danh sách rỗng/một cửa sổ, lựa chọn đúng ID cùng PID, preview mơ hồ/title/process, cache LRU và giới hạn byte, bỏ generation capture cũ, bố cục nhiều kích thước màn hình và chọn màn hình theo overlap/con trỏ.

## Chưa thể xác minh trong phiên này

- Global Option + Tab, chặn phím thực tế, Escape giữ nguyên focus và chuyển đúng cửa sổ của ứng dụng khác: **chưa có quyền Accessibility**.
- Ảnh capture thực bằng ScreenCaptureKit, thu hồi quyền trong lúc capture, thumbnail của minimized/hidden/protected windows: **chưa có Screen Recording**.
- Quyền Input Monitoring có cần bổ sung trên cấu hình người dùng hay không: cần thử tạo active event tap sau khi cấp Accessibility; không suy ra chỉ từ preflight của listener.
- Fullscreen, Mission Control, nhiều Spaces, kết nối/ngắt màn hình ngoài, Secure Input và các ứng dụng AX không chuẩn.
- Launch at Login qua một chu kỳ đăng xuất/đăng nhập; chưa tự bật tính năng này cho người dùng.
- Giữ TCC sau rebuild bằng chứng chỉ Apple Development; hiện chỉ dùng ad-hoc.
- Đo CPU/RAM trong tải cửa sổ thực; Intel/macOS 14 và bản phân phối notarized chưa được chạy thử.

Ứng dụng đã được mở bằng `run.sh`. Cấp quyền trong **QuickTab → Cài đặt…**, rồi thực hiện checklist tương tác trong README. Build thành công và kiểm tra logic không thay thế các kiểm tra hệ thống ở trên.
