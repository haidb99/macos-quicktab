import SwiftUI
import ServiceManagement
import QuickTabCore

@MainActor
final class SettingsManager: ObservableObject {
    private let defaults = UserDefaults.standard
    @Published var enabled: Bool { didSet { defaults.set(enabled, forKey: "enabled") } }
    @Published var thumbnails: Bool { didSet { defaults.set(thumbnails, forKey: "thumbnails") } }
    @Published var cardWidth: Double { didSet { defaults.set(cardWidth, forKey: "cardWidth") } }
    @Published var maximumWindows: Int { didSet { defaults.set(maximumWindows, forKey: "maximumWindows") } }
    @Published var animationDuration: Double { didSet { defaults.set(animationDuration, forKey: "animationDuration") } }
    @Published var shortcutKeyCode: UInt16 { didSet { defaults.set(Int(shortcutKeyCode), forKey: "shortcutKeyCode") } }
    @Published var shortcutModifier: UInt8 { didSet { defaults.set(Int(shortcutModifier), forKey: "shortcutModifier") } }
    @Published private(set) var loginStatus = SMAppService.mainApp.status
    @Published var message: String?
    init() {
        defaults.register(defaults: ["enabled": true, "thumbnails": true, "cardWidth": 240.0, "maximumWindows": 30, "animationDuration": 0.1, "shortcutKeyCode": 48, "shortcutModifier": 1])
        enabled = defaults.bool(forKey: "enabled")
        thumbnails = defaults.bool(forKey: "thumbnails")
        cardWidth = min(360, max(180, defaults.double(forKey: "cardWidth")))
        maximumWindows = min(100, max(1, defaults.integer(forKey: "maximumWindows")))
        animationDuration = min(0.25, max(0, defaults.double(forKey: "animationDuration")))
        shortcutKeyCode = UInt16(min(127, max(0, defaults.integer(forKey: "shortcutKeyCode"))))
        shortcutModifier = UInt8(defaults.integer(forKey: "shortcutModifier"))
        if ![1, 2, 4].contains(shortcutModifier) { shortcutModifier = 1 }
    }
    var shortcut: Shortcut { var value = Shortcut(); value.tab = shortcutKeyCode; value.modifier = shortcutModifier; return value }
    var shortcutDescription: String {
        let modifier = shortcutModifier == 2 ? "⌃ Control" : shortcutModifier == 4 ? "⌘ Command" : "⌥ Option"
        let key = [48: "Tab", 49: "Space", 36: "Return", 42: "\\" , 47: "/"][shortcutKeyCode] ?? "Keycode \(shortcutKeyCode)"
        return "\(modifier) + \(key)"
    }
    var shortcutConflictWarning: String? {
        if shortcutModifier == 4 && shortcutKeyCode == 48 {
            return "Command + Tab is reserved by macOS and may not reach QuickTab. Try Control + Tab, Option + Tab, or Command + Return."
        }
        if shortcutModifier == 4 && shortcutKeyCode == 49 {
            return "Command + Space may be reserved by Spotlight and may not reach QuickTab. Try Command + Return or Control + Tab."
        }
        return nil
    }
    func resetShortcut() { shortcutKeyCode = 48; shortcutModifier = 1 }
    var launchAtLogin: Bool { loginStatus == .enabled || loginStatus == .requiresApproval }
    func refreshLoginStatus() { loginStatus = SMAppService.mainApp.status }
    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            message = nil
        } catch { message = "Could not update Launch at Login: \(error.localizedDescription)" }
        refreshLoginStatus()
    }
}
