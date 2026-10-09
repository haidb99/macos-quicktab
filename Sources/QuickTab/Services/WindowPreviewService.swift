import AppKit
import ScreenCaptureKit
import QuickTabCore

// Main-queue confined metadata/cache; Apple's asynchronous capture runs off the main thread.
@MainActor
final class WindowPreviewService {
    private struct CachedImage {
        let image: NSImage
        let title: String
        let frame: CGRect
        let captured: Date
    }
    private var cache = CostCache<WindowID, CachedImage>(limit: 64 * 1024 * 1024)
    private var generation = RequestGeneration()
    private var items: [WindowItem] = []
    private var visible = Set<WindowID>()
    private var selected: WindowID?
    private var shareable: [SCWindow] = []
    private var contentTask: Task<Void, Never>?
    private var captures: [WindowID: Task<Void, Never>] = [:]
    private var attempted = Set<WindowID>()
    private var enabled = false
    var onImagesChanged: (() -> Void)?
    var onPermissionFailure: (() -> Void)?

    func begin(_ items: [WindowItem], enabled: Bool) {
        cancel()
        self.items = items; self.enabled = enabled
        guard enabled, CGPreflightScreenCaptureAccess() else { return }
        loadContent()
    }
    private func loadContent() {
        guard enabled, contentTask == nil else { return }
        let token = generation.current
        contentTask = Task { @MainActor [weak self] in
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
                guard let self, self.generation.accepts(token), !Task.isCancelled else { return }
                self.contentTask = nil
                self.shareable = content.windows.filter { $0.windowLayer == 0 }
                self.pump()
            } catch {
                guard let self, self.generation.accepts(token), !Task.isCancelled else { return }
                self.contentTask = nil
                if !CGPreflightScreenCaptureAccess() { self.onPermissionFailure?() }
                NSLog("QuickTab preview list: %@", error.localizedDescription)
            }
        }
    }
    func update(_ items: [WindowItem], selected: WindowID?) {
        let changed = items.filter { item in
            !self.items.contains { $0.id == item.id && $0.title == item.title && $0.frame == item.frame }
        }
        self.items = items; self.selected = selected
        cache.retain(Set(items.map(\.id)))
        for item in changed { attempted.remove(item.id) }
        for (id, task) in captures where !items.contains(where: { $0.id == id }) { task.cancel() }
        if !changed.isEmpty { loadContent() }
        pump()
    }
    func setVisible(_ id: WindowID, _ value: Bool) {
        if value { visible.insert(id) } else {
            visible.remove(id)
            if id != selected { captures[id]?.cancel() }
        }
        pump()
    }
    func images() -> [WindowID: NSImage] {
        var result: [WindowID: NSImage] = [:]
        guard enabled else { return result }
        for item in items {
            if let cached = cache.value(for: item.id), cached.title == item.title, cached.frame == item.frame {
                result[item.id] = cached.image
            }
        }
        return result
    }
    func cancel(clearCache: Bool = false) {
        generation.advance(); enabled = false
        contentTask?.cancel(); contentTask = nil
        // Keep occupied slots until the native calls actually finish; Task.cancel alone doesn't cancel SCK.
        captures.values.forEach { $0.cancel() }
        shareable = []; visible = []; attempted = []; items = []; selected = nil
        if clearCache { cache.removeAll() }
    }
    private func pump() {
        guard enabled, !shareable.isEmpty else { return }
        let candidates = shareable.map { PreviewCandidate(id: $0.windowID, pid: $0.owningApplication?.processID ?? -1, title: $0.title ?? "", frame: $0.frame) }
        let priority = items.filter { $0.id == selected } + items.filter { $0.id != selected && visible.contains($0.id) }
        for item in priority {
            guard captures.count < 2 else { break }
            guard captures[item.id] == nil, !attempted.contains(item.id), !item.minimized else { continue }
            if let cached = cache.value(for: item.id), cached.title == item.title, cached.frame == item.frame, Date().timeIntervalSince(cached.captured) < 2 { continue }
            attempted.insert(item.id)
            guard let windowID = PreviewMatcher.match(pid: item.id.pid, title: item.title, frame: item.frame, candidates: candidates),
                  let window = shareable.first(where: { $0.windowID == windowID }) else { continue }
            let token = generation.current
            captures[item.id] = Task { @MainActor [weak self] in
                do {
                    let cgImage = try await Self.capture(window)
                    guard let self else { return }
                    if self.generation.accepts(token), !Task.isCancelled, self.items.contains(where: { $0.id == item.id && $0.title == item.title && $0.frame == item.frame }) {
                        let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                        self.cache.insert(CachedImage(image: image, title: item.title, frame: item.frame, captured: Date()), for: item.id, cost: cgImage.bytesPerRow * cgImage.height)
                        self.onImagesChanged?()
                    }
                } catch {
                    if let self, self.generation.accepts(token), !Task.isCancelled {
                        if !CGPreflightScreenCaptureAccess() { self.onPermissionFailure?() }
                        NSLog("QuickTab preview capture: %@", error.localizedDescription)
                    }
                }
                if let self, self.generation.accepts(token), Task.isCancelled { self.attempted.remove(item.id) }
                self?.captures.removeValue(forKey: item.id)
                self?.pump()
            }
        }
    }
    nonisolated private static func capture(_ window: SCWindow) async throws -> CGImage {
        try Task.checkCancellation()
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        let width = max(1, window.frame.width), height = max(1, window.frame.height)
        let scale = min(2, 640 / max(width, height))
        config.width = max(1, Int(width * scale)); config.height = max(1, Int(height * scale))
        config.showsCursor = false; config.scalesToFit = true
        config.ignoreShadowsSingleWindow = true
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }
}
