import AppKit
import ApplicationServices

final class WindowActivator {
    private let manager: WindowManager
    private var queue: DispatchQueue { manager.queue }
    init(manager: WindowManager) { self.manager = manager }
    func activate(_ item: WindowItem, completion: @escaping (String?) -> Void) {
        queue.async {
            guard AXIsProcessTrusted(), self.manager.isCurrent(item), axValue(item.element, kAXRoleAttribute as CFString) != nil,
                  let app = NSRunningApplication(processIdentifier: item.id.pid), !app.isTerminated else {
                DispatchQueue.main.async { completion("The window closed or Accessibility permission is unavailable.") }; return
            }
            DispatchQueue.main.async {
                if app.isHidden { app.unhide() }
                self.queue.async {
                    if axValue(item.element, kAXMinimizedAttribute as CFString) as? Bool == true {
                        let result = AXUIElementSetAttributeValue(item.element, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
                        guard result == .success else {
                            DispatchQueue.main.async { completion("The application would not restore this window.") }; return
                        }
                    }
                    DispatchQueue.main.async {
                        guard app.activate(options: []) else { completion("macOS would not activate this application."); return }
                        self.queue.async { self.raise(item, attempt: 0, completion: completion) }
                    }
                }
            }
        }
    }
    private func raise(_ item: WindowItem, attempt: Int, completion: @escaping (String?) -> Void) {
        guard manager.isCurrent(item), AXIsProcessTrusted() else {
            DispatchQueue.main.async { completion("The window is no longer available.") }; return
        }
        AXUIElementSetAttributeValue(item.element, kAXMainAttribute as CFString, kCFBooleanTrue)
        let result = AXUIElementPerformAction(item.element, kAXRaiseAction as CFString)
        guard result == .success else {
            DispatchQueue.main.async { completion("Could not bring the window forward (AX \(result.rawValue)).") }; return
        }
        queue.asyncAfter(deadline: .now() + 0.08) {
            let appElement = AXUIElementCreateApplication(item.id.pid)
            AXUIElementSetMessagingTimeout(appElement, 0.15)
            let focused = axValue(appElement, kAXFocusedWindowAttribute as CFString)
            if let focused, CFEqual(focused, item.element) {
                DispatchQueue.main.async { completion(nil) }
            } else if attempt == 0 {
                self.raise(item, attempt: 1, completion: completion)
            } else {
                DispatchQueue.main.async { completion("The window was requested, but the application did not confirm focus. Fullscreen or Spaces may limit this operation.") }
            }
        }
    }
}
