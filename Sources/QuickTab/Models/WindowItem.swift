import AppKit
import ApplicationServices
import QuickTabCore

struct WindowItem: Identifiable {
    let id: WindowID
    let element: AXUIElement
    let appName: String
    let title: String
    let frame: CGRect
    let minimized: Bool
    let icon: NSImage?
}

func axValue(_ element: AXUIElement, _ attribute: CFString) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return nil }
    return value
}
func axFrame(_ element: AXUIElement) -> CGRect {
    var point = CGPoint.zero
    var size = CGSize.zero
    if let raw = axValue(element, kAXPositionAttribute as CFString), CFGetTypeID(raw) == AXValueGetTypeID() {
        AXValueGetValue(raw as! AXValue, .cgPoint, &point)
    }
    if let raw = axValue(element, kAXSizeAttribute as CFString), CFGetTypeID(raw) == AXValueGetTypeID() {
        AXValueGetValue(raw as! AXValue, .cgSize, &size)
    }
    return CGRect(origin: point, size: size)
}
