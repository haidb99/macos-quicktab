import Foundation
import CoreGraphics

public struct PreviewCandidate: Sendable {
    public let id: UInt32
    public let pid: Int32
    public let title: String
    public let frame: CGRect
    public init(id: UInt32, pid: Int32, title: String, frame: CGRect) {
        self.id = id; self.pid = pid; self.title = title; self.frame = frame
    }
}
public enum PreviewMatcher {
    public static func match(pid: Int32, title: String, frame: CGRect, candidates: [PreviewCandidate]) -> UInt32? {
        var matches: [PreviewCandidate] = []
        for candidate in candidates {
            guard candidate.pid == pid else { continue }
            let sameOrigin = abs(candidate.frame.minX - frame.minX) <= 3 && abs(candidate.frame.minY - frame.minY) <= 3
            let sameSize = abs(candidate.frame.width - frame.width) <= 3 && abs(candidate.frame.height - frame.height) <= 3
            if sameOrigin && sameSize { matches.append(candidate) }
        }
        // A conflicting nonempty title is never enough evidence to associate an image.
        let compatible = matches.filter { title.isEmpty || $0.title.isEmpty || $0.title == title }
        if compatible.count == 1 { return compatible[0].id }
        let exact = compatible.filter { !title.isEmpty && $0.title == title }
        return exact.count == 1 ? exact[0].id : nil
    }
}

/// Deterministic, cost-bounded LRU. Confinement to the owner's actor/queue is required.
public struct CostCache<Key: Hashable, Value> {
    private struct Entry { let value: Value; let cost: Int }
    private var entries: [Key: Entry] = [:]
    private var order: [Key] = []
    public let limit: Int
    public private(set) var cost = 0
    public init(limit: Int) { self.limit = max(0, limit) }
    public mutating func value(for key: Key) -> Value? {
        guard let entry = entries[key] else { return nil }
        order.removeAll { $0 == key }; order.append(key)
        return entry.value
    }
    public mutating func insert(_ value: Value, for key: Key, cost newCost: Int) {
        remove(key)
        guard newCost >= 0, newCost <= limit else { return }
        while cost + newCost > limit, let oldest = order.first { remove(oldest) }
        entries[key] = Entry(value: value, cost: newCost); order.append(key); cost += newCost
    }
    public mutating func remove(_ key: Key) {
        if let entry = entries.removeValue(forKey: key) { cost -= entry.cost }
        order.removeAll { $0 == key }
    }
    public mutating func retain(_ keys: Set<Key>) { for key in Array(entries.keys) where !keys.contains(key) { remove(key) } }
    public mutating func removeAll() { entries.removeAll(); order.removeAll(); cost = 0 }
}

public struct RequestGeneration {
    public private(set) var current: UInt64 = 0
    public init() {}
    @discardableResult public mutating func advance() -> UInt64 { current &+= 1; return current }
    public func accepts(_ token: UInt64) -> Bool { current == token }
}
