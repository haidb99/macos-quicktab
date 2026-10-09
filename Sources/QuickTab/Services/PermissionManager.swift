import AppKit
import ApplicationServices
import Combine

@MainActor
final class PermissionManager: ObservableObject {
    @Published private(set) var accessibility = false
    @Published private(set) var screenRecording = false
    @Published private(set) var inputMonitoring = false
    @Published var tapAvailable = false
    @Published var lastError: String?
    var onChange: (() -> Void)?
    private var tokens: [NSObjectProtocol] = []
    private var timer: Timer?
    init() {
        refresh()
        tokens.append(NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in MainActor.assumeIsolated { self?.refresh() } })
        tokens.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in MainActor.assumeIsolated { self?.refresh() } })
    }
    func refresh() {
        let oldAX = accessibility
        let oldScreen = screenRecording
        let oldInput = inputMonitoring
        accessibility = AXIsProcessTrusted()
        screenRecording = CGPreflightScreenCaptureAccess()
        inputMonitoring = CGPreflightListenEventAccess()
        if accessibility != oldAX || screenRecording != oldScreen || inputMonitoring != oldInput { onChange?() }
    }
    func watchSettings(_ visible: Bool) {
        timer?.invalidate(); timer = nil
        if visible {
            refresh()
            timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.refresh() } }
        }
    }
    func requestAccessibility() {
        _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        openPrivacy("Privacy_Accessibility")
    }
    func requestScreenRecording() {
        _ = CGRequestScreenCaptureAccess()
        refresh()
        if !screenRecording { openPrivacy("Privacy_ScreenCapture") }
    }
    func requestInputMonitoring() {
        _ = CGRequestListenEventAccess()
        openPrivacy("Privacy_ListenEvent")
    }
    func openPrivacy(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") { NSWorkspace.shared.open(url) }
    }
    deinit {
        timer?.invalidate()
        for token in tokens {
            NotificationCenter.default.removeObserver(token)
            NSWorkspace.shared.notificationCenter.removeObserver(token)
        }
    }
}
