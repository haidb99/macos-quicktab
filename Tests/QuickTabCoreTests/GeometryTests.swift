import XCTest
import CoreGraphics
@testable import QuickTabCore
final class GeometryTests: XCTestCase {
    func testAllLayoutsStayInsideDisplay() {
        for width in [640.0, 1024.0, 3840.0] {
            let frame = CGRect(x: -500, y: 0, width: width, height: 600)
            for count in [0, 1, 30, 100] {
                let result = OverlayGeometry.layout(visibleFrame: frame, count: count, preferredCardWidth: 360)
                XCTAssertTrue(frame.contains(result.frame)); XCTAssertGreaterThan(result.columns, 0)
            }
        }
    }
    func testLargestOverlapAndPointerFallback() {
        let frames = [CGRect(x: 0, y: 0, width: 1000, height: 800), CGRect(x: -1000, y: 0, width: 1000, height: 800)]
        XCTAssertEqual(OverlayGeometry.screenIndex(frames: frames, activeWindow: CGRect(x: -700, y: 20, width: 800, height: 600), pointer: CGPoint(x: 10, y: 10)), 1)
        XCTAssertEqual(OverlayGeometry.screenIndex(frames: frames, activeWindow: nil, pointer: CGPoint(x: -10, y: 10)), 1)
        XCTAssertNil(OverlayGeometry.screenIndex(frames: [], activeWindow: nil, pointer: .zero))
    }
}
