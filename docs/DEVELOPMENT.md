# Development

Use macOS 14 or newer, Swift 5.9+, and Swift Package Manager. The repository is edited in VS Code with `swiftlang.swift-vscode` and optionally CodeLLDB. Xcode is not needed to create the project, but its toolchain supplies SDKs and XCTest on machines where Command Line Tools do not.

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

CI does not attempt to grant Accessibility or Screen Recording. Manual verification must use a real keyboard and explicit user-granted permissions.

Shortcut settings use stable macOS virtual keycodes for a deliberately small set of safe keys: Tab, Space, Return, backslash, and slash. If a new key is added, update its display name, persistence validation, and core/event-monitor tests together.
