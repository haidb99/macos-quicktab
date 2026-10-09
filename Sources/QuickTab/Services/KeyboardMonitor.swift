import AppKit
import QuickTabCore

final class KeyboardMonitor {
    var onCommand: ((SwitchCommand) -> Void)?
    var onFailure: ((String) -> Void)?
    var onReady: (() -> Void)?
    private let lock = NSLock()
    private var loop: CFRunLoop?
    private var thread: Thread?
    private var enabled = true
    private var state = KeyboardState()
    private var tap: CFMachPort?
    private var shortcut = Shortcut()
    private let diagnosticURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("QuickTab-events.log")
    private func log(_ message: String) {
        guard UserDefaults.standard.bool(forKey: "quicktabEventDiagnostics") else { return }
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: diagnosticURL.path), let handle = try? FileHandle(forWritingTo: diagnosticURL) {
                try? handle.seekToEnd(); try? handle.write(contentsOf: data); try? handle.close()
            } else { try? data.write(to: diagnosticURL) }
        }
    }
    private func configuredShortcut() -> Shortcut {
        lock.lock(); defer { lock.unlock() }
        return shortcut
    }
    func isConfiguredModifierHeld() -> Bool {
        isShortcutActive(CGEventSource.flagsState(.combinedSessionState))
    }
    private func isShortcutActive(_ flags: CGEventFlags) -> Bool {
        Self.isShortcutActive(flags, modifier: configuredShortcut().modifier)
    }
    static func isShortcutActive(_ flags: CGEventFlags, modifier: UInt8) -> Bool {
        switch modifier { case 2: return flags.contains(.maskControl); case 4: return flags.contains(.maskCommand); default: return flags.contains(.maskAlternate) }
    }
    func updateShortcut(_ shortcut: Shortcut) {
        lock.lock(); self.shortcut = shortcut; let runLoop = loop; lock.unlock()
        log("shortcut updated modifier=\(shortcut.modifier) key=\(shortcut.tab) runLoop=\(runLoop != nil)")
        if let runLoop {
            CFRunLoopPerformBlock(runLoop, CFRunLoopMode.commonModes.rawValue) { [weak self] in self?.state.shortcut = shortcut }
            CFRunLoopWakeUp(runLoop)
        }
    }
    func setEnabled(_ value: Bool) {
        lock.lock()
        let changed = enabled != value
        enabled = value; let runLoop = loop
        lock.unlock()
        guard changed else { return }
        if let runLoop {
            CFRunLoopPerformBlock(runLoop, CFRunLoopMode.commonModes.rawValue) { [weak self] in self?.state.cancel(modifierHeld: self?.isShortcutActive(CGEventSource.flagsState(.combinedSessionState)) ?? false) }
            CFRunLoopWakeUp(runLoop)
        }
    }
    func start() {
        guard thread == nil else {
            lock.lock(); let runLoop = loop; lock.unlock()
            if let runLoop {
                CFRunLoopPerformBlock(runLoop, CFRunLoopMode.commonModes.rawValue) { [weak self] in
                    guard let self, let tap = self.tap else { return }
                    CGEvent.tapEnable(tap: tap, enable: true)
                    let available = CGEvent.tapIsEnabled(tap: tap)
                    DispatchQueue.main.async { [weak self] in
                        if available { self?.onReady?() }
                        else { self?.onFailure?("macOS did not enable the event tap. Check permissions and try again.") }
                    }
                }
                CFRunLoopWakeUp(runLoop)
            }
            return
        }
        let worker = Thread { [weak self] in self?.run() }
        worker.name = "QuickTab Keyboard"; thread = worker; worker.start()
    }
    private func run() {
        let mask = [CGEventType.keyDown, .keyUp, .flagsChanged].reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: mask, callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                return Unmanaged<KeyboardMonitor>.fromOpaque(context).takeUnretainedValue().receive(type, event)
            }, userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            DispatchQueue.main.async { [weak self] in
                self?.thread = nil
                self?.onFailure?("Could not create the event tap. Check Accessibility and Input Monitoring.")
            }; return
        }
        tap = port
        let runLoop = CFRunLoopGetCurrent()!
        lock.lock(); loop = runLoop; lock.unlock()
        state.shortcut = configuredShortcut()
        let source = CFMachPortCreateRunLoopSource(nil, port, 0)!
        CFRunLoopAddSource(runLoop, source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        let available = CGEvent.tapIsEnabled(tap: port)
        DispatchQueue.main.async { [weak self] in
            if available { self?.onReady?() }
            else { self?.onFailure?("macOS did not enable the event tap. Check permissions and try again.") }
        }
        CFRunLoopRun()
        CGEvent.tapEnable(tap: port, enable: false)
        CFRunLoopRemoveSource(runLoop, source, .commonModes)
        CFMachPortInvalidate(port)
        lock.lock(); loop = nil; lock.unlock()
        tap = nil
    }
    private func receive(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            state.cancel(modifierHeld: isShortcutActive(CGEventSource.flagsState(.combinedSessionState)))
            DispatchQueue.main.async { [weak self] in self?.onCommand?(.cancel) }
            if AXIsProcessTrusted(), let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            else { DispatchQueue.main.async { [weak self] in self?.onFailure?("Accessibility permission was revoked.") } }
            return Unmanaged.passUnretained(event)
        }
        lock.lock(); let allowed = enabled; lock.unlock()
        guard allowed || type == .keyUp || type == .flagsChanged else { return Unmanaged.passUnretained(event) }
        let flags = event.flags
        let shortcutActive = isShortcutActive(flags)
        log("event type=\(type.rawValue) key=\(event.getIntegerValueField(.keyboardEventKeycode)) flags=\(flags.rawValue) modifier=\(configuredShortcut().modifier) active=\(shortcutActive) stateActive=\(state.active)")
        let result = state.handle(key: UInt16(event.getIntegerValueField(.keyboardEventKeycode)), down: type == .keyDown,
            modifierActive: shortcutActive, shift: flags.contains(.maskShift), modifiersOnly: type == .flagsChanged, shortcutActive: shortcutActive)
        if let command = result.1 { DispatchQueue.main.async { [weak self] in self?.onCommand?(command) } }
        return result.0 ? nil : Unmanaged.passUnretained(event)
    }
    func cancelSession() {
        lock.lock(); let runLoop = loop; lock.unlock()
        if let runLoop {
            CFRunLoopPerformBlock(runLoop, CFRunLoopMode.commonModes.rawValue) { [weak self] in self?.state.cancel(modifierHeld: self?.isShortcutActive(CGEventSource.flagsState(.combinedSessionState)) ?? false) }
            CFRunLoopWakeUp(runLoop)
        }
    }
    func stop() {
        lock.lock(); let runLoop = loop; lock.unlock()
        if let runLoop { CFRunLoopStop(runLoop) }
    }
}
