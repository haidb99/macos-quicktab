import Foundation

public struct WindowID: Hashable, Sendable {
    public let pid: Int32
    public let generation: UInt64
    public let serial: UInt64
    public init(pid: Int32, generation: UInt64, serial: UInt64) {
        self.pid = pid; self.generation = generation; self.serial = serial
    }
}

public enum SwitchCommand: Equatable, Sendable { case step(Int), commit, cancel }
public struct Shortcut: Sendable {
    public var tab: UInt16 = 48
    public var escape: UInt16 = 53
    public var modifier: UInt8 = 1 // 1 = Option, 2 = Control, 4 = Command
    public init() {}
}
public struct KeyboardState {
    public private(set) var active = false
    private var consumed = Set<UInt16>()
    private var cancelledUntilRelease = false
    public var shortcut = Shortcut()
    public init() {}
    public mutating func reset() { active = false; consumed.removeAll(); cancelledUntilRelease = false }
    public mutating func cancel(modifierHeld: Bool) { active = false; cancelledUntilRelease = modifierHeld }
    public mutating func handle(key: UInt16, down: Bool, modifierActive: Bool, shift: Bool, modifiersOnly: Bool = false, shortcutActive: Bool? = nil) -> (Bool, SwitchCommand?) {
        let activeModifier = shortcutActive ?? modifierActive
        if modifiersOnly {
            if !activeModifier {
                cancelledUntilRelease = false
                if active { active = false; return (false, .commit) }
            }
            return (false, nil)
        }
        if !down { return (consumed.remove(key) != nil, nil) }
        if key == shortcut.escape && active {
            consumed.insert(key); active = false; cancelledUntilRelease = true
            return (true, .cancel)
        }
        if key == shortcut.tab && activeModifier {
            consumed.insert(key)
            guard !cancelledUntilRelease else { return (true, nil) }
            active = true
            return (true, .step(shift ? -1 : 1))
        }
        return (false, nil)
    }
}

public struct MRUTracker {
    public private(set) var history: [WindowID] = []
    public init() {}
    public mutating func focus(_ id: WindowID) { history.removeAll { $0 == id }; history.insert(id, at: 0) }
    public mutating func reconcile(_ live: Set<WindowID>) { history.removeAll { !live.contains($0) } }
    public func ordered(_ ids: [WindowID]) -> [WindowID] {
        let live = Set(ids)
        return history.filter { live.contains($0) } + ids.filter { !history.contains($0) }
    }
}

public struct SelectionState {
    public private(set) var ids: [WindowID] = []
    public private(set) var selected: WindowID?
    public init() {}
    public mutating func begin(_ ordered: [WindowID], focused: WindowID?, direction: Int) {
        ids = ordered
        selected = focused.flatMap { ids.contains($0) ? $0 : nil }
        step(direction)
    }
    public mutating func step(_ direction: Int) {
        guard !ids.isEmpty else { selected = nil; return }
        let index = selected.flatMap { ids.firstIndex(of: $0) }
        let base = index ?? (direction > 0 ? -1 : 0)
        selected = ids[(base + direction % ids.count + ids.count) % ids.count]
    }
    public mutating func reconcile(_ live: [WindowID]) {
        let oldIndex = selected.flatMap { ids.firstIndex(of: $0) } ?? 0
        let available = Set(live)
        ids = ids.filter { available.contains($0) } + live.filter { !ids.contains($0) }
        if selected.map({ !available.contains($0) }) ?? true {
            selected = ids.isEmpty ? nil : ids[min(oldIndex, ids.count - 1)]
        }
    }
}
