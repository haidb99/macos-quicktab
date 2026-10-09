import AppKit
import SwiftUI
import Combine
import QuickTabCore

@MainActor
final class SwitcherModel: ObservableObject {
    @Published var windows: [WindowItem] = []
    @Published var selected: WindowID?
    @Published var previews: [WindowID: NSImage] = [:]
    @Published var loading = false
    @Published var cardWidth: CGFloat = 240
    @Published var columns = 3
    @Published var animationDuration = 0.1
    var onVisibility: ((WindowID, Bool) -> Void)?
}
@MainActor
final class SwitcherController {
    let model = SwitcherModel()
    let manager = WindowManager()
    let keyboard = KeyboardMonitor()
    private let preview = WindowPreviewService()
    private var previewEnabled = false
    private var visibleCards = Set<WindowID>()
    let settings: SettingsManager
    let permissions: PermissionManager
    private lazy var activator = WindowActivator(manager: manager)
    private var panel: NSPanel?
    private var windows: [WindowItem] = []
    private var focused: WindowID?
    private var mru = MRUTracker()
    private var selection = SelectionState()
    private var active = false
    private var awaitingSnapshot = false
    private var pendingSteps: [Int] = []
    private var pendingCommit = false
    private var session: UInt64 = 0
    private var subscriptions = Set<AnyCancellable>()
    private var screenToken: NSObjectProtocol?
    private var watchdog: Timer?
    var onError: ((String) -> Void)?
    init(settings: SettingsManager, permissions: PermissionManager) {
        self.settings = settings; self.permissions = permissions
    }
    func start() {
        manager.onChange = { [weak self] items, focused in self?.update(items, focused: focused) }
        keyboard.onCommand = { [weak self] in self?.handle($0) }
        keyboard.onFailure = { [weak self] message in
            self?.permissions.tapAvailable = false; self?.permissions.lastError = message
            self?.close(); self?.onError?(message)
        }
        keyboard.onReady = { [weak self] in self?.permissions.tapAvailable = true; self?.permissions.lastError = nil }
        keyboard.updateShortcut(settings.shortcut)
        permissions.onChange = { [weak self] in self?.reconcilePermissions() }
        settings.$enabled.dropFirst().receive(on: DispatchQueue.main).sink { [weak self] enabled in
            guard let self else { return }
            self.keyboard.setEnabled(enabled && self.permissions.accessibility)
            if !enabled { self.close() }
            else { self.reconcilePermissions() }
        }.store(in: &subscriptions)
        settings.$shortcutKeyCode.combineLatest(settings.$shortcutModifier).sink { [weak self] _, _ in
            guard let self else { return }
            self.keyboard.updateShortcut(self.settings.shortcut)
            if self.active { self.close() }
        }.store(in: &subscriptions)
        settings.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self, self.active else { return }
                self.model.animationDuration = self.settings.animationDuration
                self.layout(); self.publish()
            }
        }.store(in: &subscriptions)
        screenToken = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { guard let self, self.active else { return }; self.layout() }
        }
        model.onVisibility = { [weak self] id, visible in
            guard let self else { return }
            if visible { self.visibleCards.insert(id) } else { self.visibleCards.remove(id) }
            if self.active { self.preview.setVisible(id, visible) }
        }
        preview.onImagesChanged = { [weak self] in
            guard let self, self.active else { return }
            self.model.previews = self.preview.images()
        }
        preview.onPermissionFailure = { [weak self] in self?.permissions.refresh() }
        manager.start(); reconcilePermissions()
    }
    private func reconcilePermissions() {
        let enabled = permissions.accessibility && settings.enabled
        keyboard.setEnabled(enabled)
        if enabled { keyboard.start(); manager.refresh() }
        else { permissions.tapAvailable = false; close() }
        if !permissions.screenRecording { preview.cancel(clearCache: true); model.previews = [:]; previewEnabled = false }
        if active { syncPreview() }
    }
    private func update(_ items: [WindowItem], focused: WindowID?) {
        windows = items; self.focused = focused
        mru.reconcile(Set(items.map(\.id)))
        if let focused { mru.focus(focused) }
        guard active else { return }
        if awaitingSnapshot {
            awaitingSnapshot = false; model.loading = false
            let steps = pendingSteps; pendingSteps = []
            selection.begin(Array(mru.ordered(items.map(\.id)).prefix(settings.maximumWindows)), focused: focused, direction: steps.first ?? 1)
            for direction in steps.dropFirst() { selection.step(direction) }
        } else {
            let live = Set(items.map(\.id))
            let retained = selection.ids.filter { live.contains($0) }
            let additions = items.map(\.id).filter { !retained.contains($0) }
            selection.reconcile(Array((retained + additions).prefix(settings.maximumWindows)))
        }
        publish(); layout()
        if pendingCommit { handle(.commit) }
    }
    func handle(_ command: SwitchCommand) {
        switch command {
        case .step(let direction):
            guard settings.enabled, AXIsProcessTrusted() else { close(); permissions.refresh(); return }
            if pendingCommit { close() }
            if !active {
                active = true; session &+= 1
                awaitingSnapshot = windows.isEmpty
                model.loading = awaitingSnapshot
                pendingSteps = awaitingSnapshot ? [direction] : []
                selection.begin(Array(mru.ordered(windows.map(\.id)).prefix(settings.maximumWindows)), focused: focused, direction: direction)
                publish(); show(); manager.refresh()
                let token = session
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                    guard let self, self.active, self.session == token, self.awaitingSnapshot else { return }
                    self.close(); self.onError?("The application is taking too long to respond. Try again.")
                }
            } else if awaitingSnapshot { pendingSteps.append(direction) }
            else { selection.step(direction) }
            publish()
        case .commit:
            guard active else { return }
            if awaitingSnapshot { pendingCommit = true; return }
            let item = windows.first { $0.id == selection.selected }
            close()
            if let item { activator.activate(item) { [weak self] error in
                if let error { self?.permissions.refresh(); self?.onError?(error) }
                self?.manager.refresh()
            } }
        case .cancel: close()
        }
    }
    private func publish() {
        model.windows = selection.ids.compactMap { id in windows.first { $0.id == id } }
        model.selected = selection.selected
        if active { syncPreview() }
    }
    private func syncPreview() {
        let enabled = settings.thumbnails && permissions.screenRecording
        if enabled != previewEnabled {
            previewEnabled = enabled
            preview.begin(model.windows, enabled: enabled)
        }
        preview.update(model.windows, selected: model.selected)
        for id in visibleCards { preview.setVisible(id, true) }
        model.previews = preview.images()
    }
    private func show() {
        if panel == nil {
            let p = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            p.level = .popUpMenu; p.isOpaque = false; p.backgroundColor = .clear
            p.hasShadow = true; p.hidesOnDeactivate = false; p.isReleasedWhenClosed = false
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
            p.contentView = NSHostingView(rootView: SwitcherView(model: model))
            panel = p
        }
        model.animationDuration = settings.animationDuration
        layout(); panel?.orderFrontRegardless()
        // Only while visible: recover from a swallowed modifier release or Secure Input transition.
        watchdog?.invalidate()
        watchdog = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
            guard let self else { return }
            if !AXIsProcessTrusted() { self.close(); self.permissions.refresh() }
            else if !self.keyboard.isConfiguredModifierHeld(), !self.pendingCommit {
                // Missing release is ambiguous: cancel instead of activating an unintended window.
                self.close(); self.keyboard.cancelSession()
            }
            }
        }
    }
    private func layout() {
        let screens = NSScreen.screens
        let activeFrame: CGRect?
        if let item = windows.first(where: { $0.id == focused }), let primary = screens.first {
            activeFrame = CGRect(x: item.frame.minX, y: primary.frame.maxY - item.frame.maxY, width: item.frame.width, height: item.frame.height)
        } else { activeFrame = nil }
        guard let index = OverlayGeometry.screenIndex(frames: screens.map(\.frame), activeWindow: activeFrame, pointer: NSEvent.mouseLocation) else { return }
        let geometry = OverlayGeometry.layout(visibleFrame: screens[index].visibleFrame, count: model.windows.count, preferredCardWidth: settings.cardWidth)
        model.cardWidth = geometry.cardWidth; model.columns = geometry.columns
        panel?.setFrame(geometry.frame, display: true)
    }
    private func close() {
        active = false; awaitingSnapshot = false; pendingCommit = false; pendingSteps = []
        watchdog?.invalidate(); watchdog = nil
        preview.cancel(); previewEnabled = false; model.previews = [:]
        panel?.orderOut(nil)
    }
    func stop() { close(); keyboard.stop() }
    deinit { if let screenToken { NotificationCenter.default.removeObserver(screenToken) } }
}
