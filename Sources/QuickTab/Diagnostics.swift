import AppKit
import SwiftUI
import QuickTabCore

/// Explicit developer commands. They never request TCC access or synthesize global input.
@MainActor
enum Diagnostics {
    static func printPermissions() {
        let report: [String: Any] = [
            "bundleIdentifier": Bundle.main.bundleIdentifier ?? "unbundled",
            "bundlePath": Bundle.main.bundlePath,
            "accessibility": AXIsProcessTrusted(),
            "screenRecording": CGPreflightScreenCaptureAccess(),
            "inputMonitoring": CGPreflightListenEventAccess(),
            "shortcutKeyCode": UserDefaults.standard.integer(forKey: "shortcutKeyCode"),
            "shortcutModifier": UserDefaults.standard.integer(forKey: "shortcutModifier"),
            "eventDiagnosticsLog": URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("QuickTab-events.log").path,
            "system": ProcessInfo.processInfo.operatingSystemVersionString
        ]
        do {
            let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            print(String(decoding: data, as: UTF8.self))
        } catch { fputs("Diagnostics: \(error)\n", stderr) }
    }
    static func renderUI(to directory: String) {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let model = SwitcherModel()
        let names = ["Finder", "Terminal", "Safari", "Visual Studio Code", "Notes"]
        let titles = ["Downloads — preview", "Development — preview", "A deliberately long title to test truncation", "Project A — preview", ""]
        model.windows = names.enumerated().map { index, name in
            WindowItem(id: WindowID(pid: Int32(index + 1), generation: 1, serial: UInt64(index)),
                       element: AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier),
                       appName: name, title: titles[index], frame: CGRect(x: 0, y: 0, width: 900, height: 600),
                       minimized: index == 3, icon: NSImage(systemSymbolName: index == 0 ? "folder.fill" : "macwindow", accessibilityDescription: name))
        }
        model.selected = model.windows[1].id
        let settings = SettingsManager(), permissions = PermissionManager()
        let views: [(String, NSView, NSSize)] = [
            ("switcher", NSHostingView(rootView: SwitcherView(model: model)), NSSize(width: 800, height: 570)),
            ("settings", NSHostingView(rootView: SettingsView(settings: settings, permissions: permissions, onboarding: true)), NSSize(width: 600, height: 800))
        ]
        var windows: [NSWindow] = []
        for (_, view, size) in views {
            let window = NSPanel(contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.appearance = NSAppearance(named: .darkAqua)
            window.contentView = view
            window.center(); window.orderFrontRegardless()
            windows.append(window)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            do {
                try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
                for (name, view, _) in views {
                    view.layoutSubtreeIfNeeded()
                    guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw RenderError.bitmap }
                    view.cacheDisplay(in: view.bounds, to: bitmap)
                    guard let data = bitmap.representation(using: .png, properties: [:]) else { throw RenderError.bitmap }
                    let path = URL(fileURLWithPath: directory).appendingPathComponent(name + ".png")
                    try data.write(to: path)
                    print("Rendered \(path.path), \(bitmap.pixelsWide)×\(bitmap.pixelsHigh)")
                }
                windows.forEach { $0.orderOut(nil) }
                permissions.watchSettings(false)
                app.terminate(nil)
            } catch { fputs("Render failed: \(error)\n", stderr); exit(1) }
        }
        app.run()
    }
    private enum RenderError: Error { case bitmap }
}
