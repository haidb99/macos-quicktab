import CoreGraphics

public struct OverlayGeometry {
    public let frame: CGRect
    public let cardWidth: CGFloat
    public let columns: Int
    public static func layout(visibleFrame: CGRect, count: Int, preferredCardWidth: CGFloat) -> OverlayGeometry {
        let available = visibleFrame.insetBy(dx: min(24, visibleFrame.width / 8), dy: min(24, visibleFrame.height / 8))
        let card = min(preferredCardWidth, max(1, available.width - 46))
        let columns = max(1, min(max(1, count), Int((available.width - 34) / (card + 12))))
        let rows = max(1, (count + columns - 1) / columns)
        let width = min(available.width, CGFloat(columns) * (card + 12) + 34)
        let height = min(available.height, CGFloat(rows) * (max(0, card - 24) * 0.6 + 94) + 90)
        return OverlayGeometry(frame: CGRect(x: available.midX - width / 2, y: available.midY - height / 2, width: width, height: height), cardWidth: card, columns: columns)
    }
    /// Inputs share AppKit's bottom-left coordinate space.
    public static func screenIndex(frames: [CGRect], activeWindow: CGRect?, pointer: CGPoint) -> Int? {
        if let activeWindow {
            var best: (Int, CGFloat)?
            for (index, frame) in frames.enumerated() {
                let intersection = frame.intersection(activeWindow)
                let area = intersection.isNull ? 0 : intersection.width * intersection.height
                if area > (best?.1 ?? 0) { best = (index, area) }
            }
            if let best { return best.0 }
        }
        return frames.firstIndex { $0.contains(pointer) } ?? (frames.isEmpty ? nil : 0)
    }
}
