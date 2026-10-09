# Troubleshooting

## Command + Tab không mở QuickTab

`Command + Tab` trùng với App Switcher tích hợp của macOS. Hệ thống có thể ưu tiên tổ hợp này trước event tap của QuickTab. Khi đó hãy dùng `Control + Tab`, `Option + Tab` hoặc `Command + Return`. QuickTab sẽ hiển thị cảnh báo trong Settings nhưng không tự đổi lựa chọn của bạn.

## Option + Tab does nothing

Open QuickTab Settings and confirm Accessibility. Quit duplicate copies, open `/Applications/QuickTab.app`, and grant permission to that exact bundle. If the event tap still fails, inspect Input Monitoring and run `--diagnostics`.

## Tab leaks into another app

Quit and relaunch QuickTab after granting permission. The tap consumes Tab while Option is held and tracks matching key-up events. Secure Input, the lock screen, and system security controls may prevent interception.

## Thumbnails are blank

Grant Screen Recording and relaunch if macOS requests it. Protected, minimized, hidden, fullscreen, or ambiguous windows may show an icon placeholder. Switching does not depend on thumbnails.

## Gatekeeper blocks the app

Ad-hoc builds are for internal use and may require Control-click → Open. Public releases need Developer ID signing and notarization. Do not disable Gatekeeper globally.

## Accessibility permission disappeared

Confirm the app path and bundle ID, remove stale duplicate entries, then add the app currently used. Keep the same signing identity and `com.local.quicktab` identifier when possible.
