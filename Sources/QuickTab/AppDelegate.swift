import AppKit
import SwiftUI
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private let settings = SettingsManager()
    private let permissions = PermissionManager()
    private lazy var controller = SwitcherController(settings: settings, permissions: permissions)
    private var settingsWindow: NSWindow?
    private var enableItem: NSMenuItem!
    private var statusText: NSMenuItem!
    private var subscriptions = Set<AnyCancellable>()
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"), let icon = NSImage(contentsOf: iconURL) {
            icon.isTemplate = true
            icon.size = NSSize(width: 18, height: 18)
            statusItem.button?.image = icon
        } else {
            statusItem.button?.image = NSImage(systemSymbolName: "rectangle.on.rectangle", accessibilityDescription: "QuickTab")
        }
        let menu = NSMenu()
        statusText = menu.addItem(withTitle: "QuickTab", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        enableItem = menu.addItem(withTitle: "Enable QuickTab", action: #selector(toggleEnabled), keyEquivalent: "")
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit QuickTab", action: #selector(quit), keyEquivalent: "q")
        for item in menu.items { item.target = self }
        statusItem.menu = menu
        controller.onError = { [weak self] message in
            self?.permissions.lastError = message
            self?.statusItem.button?.toolTip = message
            NSLog("QuickTab: %@", message)
        }
        settings.$enabled.sink { [weak self] enabled in self?.enableItem?.state = enabled ? .on : .off }.store(in: &subscriptions)
        permissions.$tapAvailable.combineLatest(settings.$enabled).sink { [weak self] available, enabled in
            self?.statusText?.title = !enabled ? "Disabled" : (available ? "Use your shortcut to switch windows" : "Open Settings to review permissions")
        }.store(in: &subscriptions)
        controller.start()
        let firstLaunch = !UserDefaults.standard.bool(forKey: "onboardingShown")
        showSettings(onboarding: firstLaunch)
        UserDefaults.standard.set(true, forKey: "onboardingShown")
    }
    @objc private func toggleEnabled() { settings.enabled.toggle() }
    @objc private func openSettings() { showSettings(onboarding: false) }
    private func showSettings(onboarding: Bool) {
        if settingsWindow == nil {
            let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 580, height: 730), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "QuickTab — Settings"; window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(settings: settings, permissions: permissions, onboarding: onboarding))
            window.delegate = self; window.center(); settingsWindow = window
        }
        permissions.watchSettings(true); settings.refreshLoginStatus()
        NSApp.activate(); settingsWindow?.makeKeyAndOrderFront(nil)
    }
    func windowWillClose(_ notification: Notification) { permissions.watchSettings(false) }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings(onboarding: false)
        return true
    }
    @objc private func quit() { NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) { controller.stop() }
}
