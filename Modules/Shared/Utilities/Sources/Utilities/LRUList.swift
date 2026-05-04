import Foundation

public final class LRUList<Key: Hashable> {
    private final class Node {
        let key: Key
        var previous: Node?
        var next: Node?

        init(key: Key) {
            self.key = key
        }
    }

    private var nodes: [Key: Node] = [:]
    private var head: Node?
    private var tail: Node?

    public init() {}

    public var count: Int {
        nodes.count
    }

    public func touch(_ key: Key) {
        if let node = nodes[key] {
            moveToFront(node)
            return
        }

        let node = Node(key: key)
        nodes[key] = node
        insertAtFront(node)
    }

    public func remove(_ key: Key) {
        guard let node = nodes.removeValue(forKey: key) else { return }
        unlink(node)
    }

    @discardableResult
    public func removeLast() -> Key? {
        guard let node = tail else { return nil }
        let key = node.key
        remove(key)
        return key
    }

    public func removeAll() {
        nodes.removeAll()
        head = nil
        tail = nil
    }

    private func insertAtFront(_ node: Node) {
        node.previous = nil
        node.next = head
        head?.previous = node
        head = node

        if tail == nil {
            tail = node
        }
    }

    private func moveToFront(_ node: Node) {
        guard head !== node else { return }
        unlink(node)
        insertAtFront(node)
    }

    private func unlink(_ node: Node) {
        let previous = node.previous
        let next = node.next

        previous?.next = next
        next?.previous = previous

        if head === node {
            head = next
        }

        if tail === node {
            tail = previous
        }

        node.previous = nil
        node.next = nil
    }
}
