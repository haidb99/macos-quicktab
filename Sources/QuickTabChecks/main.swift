import Foundation
import CoreGraphics
import QuickTabCore

var passed = 0
func check(_ name: String, _ body: () -> Bool) {
    guard body() else { fputs("FAIL: \(name)\n", stderr); exit(1) }
    passed += 1; print("PASS: \(name)")
}
let a = WindowID(pid: 1, generation: 1, serial: 1)
let b = WindowID(pid: 1, generation: 1, serial: 2)
let c = WindowID(pid: 2, generation: 2, serial: 3)
check("Fast Option release preserves commit and swallows Tab up") {
    var s = KeyboardState()
    let down = s.handle(key: 48, down: true, modifierActive: true, shift: false)
    let up = s.handle(key: 58, down: false, modifierActive: false, shift: false, modifiersOnly: true)
    return down.0 && down.1 == .step(1) && up.1 == .commit && s.handle(key: 48, down: false, modifierActive: false, shift: false).0
}
check("Escape cancels until Option is released") {
    var s = KeyboardState(); _ = s.handle(key: 48, down: true, modifierActive: true, shift: false)
    let escape = s.handle(key: 53, down: true, modifierActive: true, shift: false)
    return escape.1 == .cancel && s.handle(key: 48, down: true, modifierActive: true, shift: false).1 == nil && s.handle(key: 58, down: false, modifierActive: false, shift: false, modifiersOnly: true).1 == nil
}
check("Repeat and reverse generate one step per event") {
    var s = KeyboardState()
    return (0..<8).allSatisfy { _ in s.handle(key: 48, down: true, modifierActive: true, shift: false).1 == .step(1) } && s.handle(key: 48, down: true, modifierActive: true, shift: true).1 == .step(-1)
}
check("Holding the other Option does not commit") {
    var s = KeyboardState(); _ = s.handle(key: 48, down: true, modifierActive: true, shift: false)
    return s.handle(key: 58, down: false, modifierActive: true, shift: false, modifiersOnly: true).1 == nil && s.handle(key: 61, down: false, modifierActive: false, shift: false, modifiersOnly: true).1 == .commit
}
check("Tap reset cannot commit stale selection") {
    var s = KeyboardState(); _ = s.handle(key: 48, down: true, modifierActive: true, shift: false); s.reset()
    return s.handle(key: 58, down: false, modifierActive: false, shift: false, modifiersOnly: true).1 == nil
}
check("Plain Tab and unrelated keys pass through") {
    var s = KeyboardState()
    return !s.handle(key: 48, down: true, modifierActive: false, shift: false).0 && !s.handle(key: 0, down: true, modifierActive: true, shift: false).0
}
check("Configured modifier can replace Option without changing cycling") {
    var s = KeyboardState()
    guard s.handle(key: 48, down: true, modifierActive: false, shift: false, shortcutActive: false).1 == nil else { return false }
    let first = s.handle(key: 48, down: true, modifierActive: true, shift: false, shortcutActive: true)
    let release = s.handle(key: 58, down: false, modifierActive: false, shift: false, modifiersOnly: true, shortcutActive: false)
    return first.1 == .step(1) && release.1 == .commit
}
check("MRU switches back to the previous window") {
    var m = MRUTracker(); m.focus(b); m.focus(a)
    var s = SelectionState(); s.begin(m.ordered([a,b,c]), focused: a, direction: 1)
    guard s.selected == b else { return false }; m.focus(b)
    s.begin(m.ordered([a,b,c]), focused: b, direction: 1)
    return s.selected == a
}
check("MRU identity is independent of title and rejects reused PID") {
    var m = MRUTracker(); m.focus(a)
    guard m.ordered([a,b]) == [a,b] else { return false }
    let replacement = WindowID(pid: a.pid, generation: 3, serial: a.serial)
    m.reconcile([replacement,b]); return m.history.isEmpty && m.ordered([replacement,b]) == [replacement,b]
}
check("Session order freezes while new windows append") {
    var s = SelectionState(); s.begin([a,b], focused: a, direction: 1); s.reconcile([b,c,a])
    return s.ids == [a,b,c] && s.selected == b
}
check("Closing selected window chooses its next surviving neighbor") {
    var s = SelectionState(); s.begin([a,b,c], focused: a, direction: 1); s.reconcile([a,c])
    return s.selected == c
}
check("Empty and single-window selections are safe") {
    var s = SelectionState(); s.begin([], focused: nil, direction: 1)
    guard s.selected == nil else { return false }
    s.begin([a], focused: a, direction: -1); s.step(1); return s.selected == a
}
check("Reverse wraps to last window") {
    var s = SelectionState(); s.begin([a,b,c], focused: a, direction: -1); return s.selected == c
}
let frame = CGRect(x: 20, y: 40, width: 900, height: 600)
check("Preview matching rejects ambiguity and wrong process") {
    let candidates = [PreviewCandidate(id: 1, pid: 1, title: "A", frame: frame), PreviewCandidate(id: 2, pid: 1, title: "A", frame: frame)]
    return PreviewMatcher.match(pid: 1, title: "A", frame: frame, candidates: candidates) == nil && PreviewMatcher.match(pid: 2, title: "A", frame: frame, candidates: candidates) == nil
}
check("Preview matching uses title to disambiguate identical frames") {
    let candidates = [PreviewCandidate(id: 1, pid: 1, title: "A", frame: frame), PreviewCandidate(id: 2, pid: 1, title: "B", frame: frame)]
    return PreviewMatcher.match(pid: 1, title: "B", frame: frame, candidates: candidates) == 2
}
check("Cache evicts least recently used image and enforces byte budget") {
    var cache = CostCache<Int,String>(limit: 8)
    cache.insert("a", for: 1, cost: 4); cache.insert("b", for: 2, cost: 4)
    _ = cache.value(for: 1); cache.insert("c", for: 3, cost: 4)
    return cache.cost == 8 && cache.value(for: 2) == nil && cache.value(for: 1) == "a"
}
check("Cache rejects oversized entries and releases closed windows") {
    var cache = CostCache<Int,String>(limit: 4); cache.insert("large", for: 1, cost: 8)
    cache.insert("small", for: 2, cost: 4); cache.retain([])
    return cache.cost == 0 && cache.value(for: 1) == nil
}
check("Cancelled capture generations discard stale completion") {
    var generation = RequestGeneration(); let token = generation.advance(); generation.advance()
    return !generation.accepts(token) && generation.accepts(generation.current)
}
check("Disabling during held Tab still consumes its matching key up") {
    var s = KeyboardState(); _ = s.handle(key: 48, down: true, modifierActive: true, shift: false)
    s.cancel(modifierHeld: true)
    return s.handle(key: 48, down: false, modifierActive: true, shift: false).0 && s.handle(key: 58, down: false, modifierActive: false, shift: false, modifiersOnly: true).1 == nil
}
check("Recovery after a missing release allows the next chord") {
    var s = KeyboardState(); _ = s.handle(key: 48, down: true, modifierActive: true, shift: false)
    s.cancel(modifierHeld: false)
    return s.handle(key: 48, down: true, modifierActive: true, shift: false).1 == .step(1)
}
check("Selection resolves the exact window among windows sharing a PID") {
    var s = SelectionState(); s.begin([a,b], focused: a, direction: 1)
    let resolved = [a,b].first { $0 == s.selected }
    return resolved == b && resolved != a
}
check("Overlay fits small and large displays with many windows") {
    for width in [640.0, 1024.0, 3840.0] {
        let screen = CGRect(x: -500, y: 20, width: width, height: 600)
        for count in [0, 1, 30, 100] {
            let layout = OverlayGeometry.layout(visibleFrame: screen, count: count, preferredCardWidth: 360)
            guard screen.contains(layout.frame), layout.columns > 0, layout.cardWidth > 0 else { return false }
        }
    }
    return true
}
check("Screen choice uses overlap then pointer for offscreen windows") {
    let frames = [CGRect(x: 0, y: 0, width: 1000, height: 800), CGRect(x: -1000, y: 0, width: 1000, height: 800)]
    let active = CGRect(x: -700, y: 20, width: 800, height: 600)
    let first = OverlayGeometry.screenIndex(frames: frames, activeWindow: active, pointer: CGPoint(x: 10, y: 10))
    let fallback = OverlayGeometry.screenIndex(frames: frames, activeWindow: CGRect(x: 3000, y: 0, width: 400, height: 300), pointer: CGPoint(x: -10, y: 10))
    return first == 1 && fallback == 1 && OverlayGeometry.screenIndex(frames: [], activeWindow: nil, pointer: .zero) == nil
}
print("\(passed) checks passed")
