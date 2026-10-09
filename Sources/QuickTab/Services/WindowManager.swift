import AppKit
import ApplicationServices
import QuickTabCore

// All AX access and registry mutations are confined to this serial queue.
final class WindowManager {
    let queue = DispatchQueue(label: "com.local.quicktab.accessibility", qos: .userInitiated)
    var onChange: (([WindowItem], WindowID?) -> Void)?
    private var registry: [WindowItem] = []
    private var serial: UInt64 = 0
    private var generation: UInt64 = 0
    private var processes: [pid_t: (Date?, UInt64)] = [:]
    private var observers: [pid_t: AXObserver] = [:]
    private var workspaceTokens: [NSObjectProtocol] = []
    private var pending: DispatchWorkItem?

    func start() {
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification,
                     NSWorkspace.didActivateApplicationNotification, NSWorkspace.didHideApplicationNotification,
                     NSWorkspace.didUnhideApplicationNotification, NSWorkspace.activeSpaceDidChangeNotification] {
            workspaceTokens.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.refresh() })
        }
        refresh()
    }
    func refresh() {
        queue.async { [weak self] in
            guard let self else { return }
            guard self.pending == nil else { return }
            let work = DispatchWorkItem { [weak self] in self?.pending = nil; self?.scan() }
            self.pending = work
            self.queue.asyncAfter(deadline: .now() + 0.03, execute: work)
        }
    }
    private func installObserver(_ pid: pid_t, app: AXUIElement) {
        guard observers[pid] == nil else { return }
        var observer: AXObserver?
        let result = AXObserverCreate(pid, { _, _, _, context in
            guard let context else { return }
            Unmanaged<WindowManager>.fromOpaque(context).takeUnretainedValue().refresh()
        }, &observer)
        guard result == .success, let observer else { return }
        observers[pid] = observer
        let context = Unmanaged.passUnretained(self).toOpaque()
        for notification in [kAXWindowCreatedNotification, kAXFocusedWindowChangedNotification, kAXApplicationActivatedNotification] {
            AXObserverAddNotification(observer, app, notification as CFString, context)
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
    }
    private func scan() {
        guard AXIsProcessTrusted() else {
            registry = []
            DispatchQueue.main.async { [weak self] in self?.onChange?([], nil) }
            return
        }
        let apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        let pids = Set(apps.map(\.processIdentifier))
        for pid in Array(processes.keys) where !pids.contains(pid) { removeProcess(pid) }
        var items: [WindowItem] = []
        var focused: WindowID?
        let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        for app in apps {
            let pid = app.processIdentifier
            if processes[pid] == nil || processes[pid]?.0 != app.launchDate {
                removeProcess(pid); generation += 1; processes[pid] = (app.launchDate, generation)
            }
            let appElement = AXUIElementCreateApplication(pid)
            AXUIElementSetMessagingTimeout(appElement, 0.15)
            installObserver(pid, app: appElement)
            var rawWindows: CFTypeRef?
            let windowResult = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &rawWindows)
            if windowResult == .cannotComplete {
                // A temporarily unresponsive process must not erase its window identities/MRU.
                items.append(contentsOf: registry.filter { $0.id.pid == pid && $0.id.generation == processes[pid]?.1 })
                continue
            }
            let windows = rawWindows as? [AXUIElement] ?? []
            let appIcon = app.icon
            let focusedElement = axValue(appElement, kAXFocusedWindowAttribute as CFString)
            for element in windows {
                let role = axValue(element, kAXRoleAttribute as CFString) as? String
                let subrole = axValue(element, kAXSubroleAttribute as CFString) as? String
                guard role == kAXWindowRole, subrole == nil || subrole == kAXStandardWindowSubrole || subrole == kAXDialogSubrole else { continue }
                let frame = axFrame(element)
                guard frame.width > 1, frame.height > 1 else { continue }
                let epoch = processes[pid]!.1
                let existing = registry.first { $0.id.pid == pid && $0.id.generation == epoch && CFEqual($0.element, element) }
                let id: WindowID
                if let existing { id = existing.id } else {
                    serial += 1; id = WindowID(pid: pid, generation: epoch, serial: serial)
                }
                let title = axValue(element, kAXTitleAttribute as CFString) as? String ?? ""
                items.append(WindowItem(id: id, element: element, appName: app.localizedName ?? "Application", title: title,
                    frame: frame, minimized: axValue(element, kAXMinimizedAttribute as CFString) as? Bool ?? false, icon: appIcon))
                if pid == frontPID, let focusedElement, CFEqual(focusedElement, element) { focused = id }
                if let observer = observers[pid] {
                    for notification in [kAXUIElementDestroyedNotification, kAXTitleChangedNotification, kAXWindowMiniaturizedNotification, kAXWindowDeminiaturizedNotification] {
                        AXObserverAddNotification(observer, element, notification as CFString, Unmanaged.passUnretained(self).toOpaque())
                    }
                }
            }
        }
        if NSWorkspace.shared.frontmostApplication?.processIdentifier != frontPID {
            focused = nil
            refresh()
        }
        registry = items
        DispatchQueue.main.async { [weak self] in self?.onChange?(items, focused) }
    }
    // Must be called on queue, immediately before an activation transaction.
    func isCurrent(_ item: WindowItem) -> Bool {
        guard let process = processes[item.id.pid], process.1 == item.id.generation,
              let app = NSRunningApplication(processIdentifier: item.id.pid), app.launchDate == process.0 else { return false }
        return registry.contains { $0.id == item.id && CFEqual($0.element, item.element) }
    }
    private func removeProcess(_ pid: pid_t) {
        if let observer = observers.removeValue(forKey: pid) {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        processes.removeValue(forKey: pid)
    }
    deinit {
        workspaceTokens.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        for observer in observers.values { CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes) }
    }
}
