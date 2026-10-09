# Development

Use macOS 14 or newer, Swift 5.9+, and Swift Package Manager. The repository is edited in VS Code with `swiftlang.swift-vscode` and optionally CodeLLDB. Xcode is not needed to create the project, but its toolchain supplies SDKs and XCTest on machines where Command Line Tools do not.

Command Line Tools are enough for `swift build` and `swift run QuickTabChecks`. Install a compatible full Xcode release and select it with `xcode-select` when you need `swift test` and XCTest:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
xcodebuild -version
```

```bash
swift build
swift run QuickTabChecks
swift test
```

Use `./build.sh` to create the app bundle and `./package-dmg.sh` to create a drag-and-drop installer. Use `--diagnostics` to inspect TCC state without requesting permissions.

The app icon source is `Resources/AppIcon.iconset`; `Resources/AppIcon.icns` is generated with `iconutil` and copied into the signed bundle by `build.sh`. If the iconset changes, regenerate the ICNS before building.

Use the VS Code tasks and `Debug QuickTab.app` launch configuration. If TCC associates a debug process differently, launch with `./run.sh` and attach LLDB to the running process. Check logs with:

```bash
log stream --predicate 'process == "QuickTab"' --level info
```

When event diagnostics are enabled, keyboard events are written to the temporary `QuickTab-events.log` path printed by `--diagnostics`. Do not attach logs containing unrelated application names or private data.

CI does not attempt to grant Accessibility or Screen Recording. Manual verification must use a real keyboard and explicit user-granted permissions.

Shortcut settings use stable macOS virtual keycodes for a deliberately small set of safe keys: Tab, Space, Return, backslash, and slash. If a new key is added, update its display name, persistence validation, and core/event-monitor tests together.
