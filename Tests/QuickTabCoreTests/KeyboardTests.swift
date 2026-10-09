import XCTest
@testable import QuickTabCore
final class KeyboardTests: XCTestCase {
    func testRepeatAndShiftAreSeparateSteps() {
        var state = KeyboardState()
        for _ in 0..<5 { XCTAssertEqual(state.handle(key: 48, down: true, modifierActive: true, shift: false).1, .step(1)) }
        XCTAssertEqual(state.handle(key: 48, down: true, modifierActive: true, shift: true).1, .step(-1))
    }
    func testHoldingOtherOptionDoesNotCommit() {
        var state = KeyboardState()
        _ = state.handle(key: 48, down: true, modifierActive: true, shift: false)
        XCTAssertNil(state.handle(key: 58, down: false, modifierActive: true, shift: false, modifiersOnly: true).1)
        XCTAssertEqual(state.handle(key: 61, down: false, modifierActive: false, shift: false, modifiersOnly: true).1, .commit)
    }
    func testResetCancelsWithoutCommit() {
        var state = KeyboardState()
        _ = state.handle(key: 48, down: true, modifierActive: true, shift: false)
        state.reset()
        XCTAssertNil(state.handle(key: 58, down: false, modifierActive: false, shift: false, modifiersOnly: true).1)
    }
    func testUnrelatedKeysPassThrough() {
        var state = KeyboardState()
        XCTAssertFalse(state.handle(key: 48, down: true, modifierActive: false, shift: false).0)
        XCTAssertFalse(state.handle(key: 0, down: true, modifierActive: true, shift: false).0)
        XCTAssertFalse(state.handle(key: 53, down: true, modifierActive: true, shift: false).0)
    }
    func testSingleWindowAndNewGeneration() {
        let a = WindowID(pid: 12, generation: 1, serial: 1)
        let replacement = WindowID(pid: 12, generation: 2, serial: 1)
        var mru = MRUTracker(); mru.focus(a); mru.reconcile([replacement])
        XCTAssertEqual(mru.ordered([replacement]), [replacement])
        var selection = SelectionState(); selection.begin([a], focused: a, direction: 1)
        XCTAssertEqual(selection.selected, a)
        selection.step(-1); XCTAssertEqual(selection.selected, a)
    }
    func testFrozenOrderAndNewWindow() {
        let ids = (1...4).map { WindowID(pid: 1, generation: 1, serial: UInt64($0)) }
        var selection = SelectionState(); selection.begin(Array(ids.prefix(3)), focused: ids[0], direction: 1)
        selection.reconcile([ids[2], ids[0], ids[1], ids[3]])
        XCTAssertEqual(selection.ids, ids)
        XCTAssertEqual(selection.selected, ids[1])
    }
}
