import XCTest
import CoreGraphics
@testable import QuickTabCore

final class PreviewTests: XCTestCase {
    func testAmbiguousPreviewDoesNotSelectArbitrarily() {
        let frame = CGRect(x: 0, y: 0, width: 800, height: 600)
        let candidates = [PreviewCandidate(id: 1, pid: 10, title: "Same", frame: frame), PreviewCandidate(id: 2, pid: 10, title: "Same", frame: frame)]
        XCTAssertNil(PreviewMatcher.match(pid: 10, title: "Same", frame: frame, candidates: candidates))
    }
    func testPreviewRequiresCompatibleTitleAndProcess() {
        let frame = CGRect(x: 0, y: 0, width: 800, height: 600)
        let candidates = [PreviewCandidate(id: 1, pid: 10, title: "One", frame: frame), PreviewCandidate(id: 2, pid: 10, title: "Two", frame: frame)]
        XCTAssertEqual(PreviewMatcher.match(pid: 10, title: "Two", frame: frame, candidates: candidates), 2)
        XCTAssertNil(PreviewMatcher.match(pid: 10, title: "Three", frame: frame, candidates: candidates))
        XCTAssertNil(PreviewMatcher.match(pid: 20, title: "Two", frame: frame, candidates: candidates))
    }
    func testCacheBudgetAndLRU() {
        var cache = CostCache<Int, String>(limit: 8)
        cache.insert("one", for: 1, cost: 4); cache.insert("two", for: 2, cost: 4)
        _ = cache.value(for: 1); cache.insert("three", for: 3, cost: 4)
        XCTAssertNil(cache.value(for: 2)); XCTAssertEqual(cache.cost, 8)
        cache.insert("too large", for: 4, cost: 9)
        XCTAssertNil(cache.value(for: 4)); XCTAssertEqual(cache.cost, 8)
        cache.retain([3]); XCTAssertEqual(cache.cost, 4)
        cache.removeAll(); XCTAssertEqual(cache.cost, 0)
    }
    func testStaleCaptureGeneration() {
        var generation = RequestGeneration()
        let token = generation.advance(); generation.advance()
        XCTAssertFalse(generation.accepts(token)); XCTAssertTrue(generation.accepts(generation.current))
    }
}
