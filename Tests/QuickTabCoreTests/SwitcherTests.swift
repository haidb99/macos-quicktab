import XCTest
@testable import QuickTabCore
final class SwitcherTests: XCTestCase {
    let a = WindowID(pid: 1, generation: 1, serial: 1)
    let b = WindowID(pid: 1, generation: 1, serial: 2)
    let c = WindowID(pid: 2, generation: 2, serial: 3)
    func testQuickReleaseAndKeyUp() {
        var state = KeyboardState()
        XCTAssertEqual(state.handle(key: 48, down: true, modifierActive: true, shift: false).1, .step(1))
        XCTAssertEqual(state.handle(key: 58, down: false, modifierActive: false, shift: false, modifiersOnly: true).1, .commit)
        XCTAssertTrue(state.handle(key: 48, down: false, modifierActive: false, shift: false).0)
    }
    func testEscapeDoesNotCommit() {
        var state = KeyboardState()
        _ = state.handle(key: 48, down: true, modifierActive: true, shift: false)
        XCTAssertEqual(state.handle(key: 53, down: true, modifierActive: true, shift: false).1, .cancel)
        XCTAssertNil(state.handle(key: 48, down: true, modifierActive: true, shift: false).1)
        XCTAssertNil(state.handle(key: 58, down: false, modifierActive: false, shift: false, modifiersOnly: true).1)
    }
    func testMRUToggleAndReconciliation() {
        var mru = MRUTracker(); mru.focus(b); mru.focus(a)
        var selection = SelectionState()
        selection.begin(mru.ordered([a,b,c]), focused: a, direction: 1)
        XCTAssertEqual(selection.selected, b)
        mru.focus(b)
        selection.begin(mru.ordered([a,b,c]), focused: b, direction: 1)
        XCTAssertEqual(selection.selected, a)
        selection.reconcile([b,c]); XCTAssertEqual(selection.selected, c)
        mru.reconcile([b,c]); XCTAssertEqual(mru.history, [b])
    }
    func testReverseRepeatAndEmpty() {
        var selection = SelectionState(); selection.begin([a,b,c], focused: a, direction: -1)
        XCTAssertEqual(selection.selected, c)
        selection.step(-1); XCTAssertEqual(selection.selected, b)
        selection.reconcile([]); selection.step(1); XCTAssertNil(selection.selected)
    }
}
