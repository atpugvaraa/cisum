import Foundation
import Observation
import Models
import Services

@Observable
@MainActor
public final class QueueManager {
    public private(set) var queue: [PlaybackQueueEntry] = []
    public var queuePosition: Int = 0
    
    public init() {}
    
    public var currentEntry: PlaybackQueueEntry? {
        guard queue.indices.contains(queuePosition) else { return nil }
        return queue[queuePosition]
    }
    
    public var canGoNext: Bool {
        queuePosition + 1 < queue.count
    }
    
    public var canGoPrevious: Bool {
        queuePosition > 0
    }
    
    public func setQueue(_ entries: [PlaybackQueueEntry], position: Int = 0) {
        self.queue = entries
        self.queuePosition = position
    }
    
    public func clear() {
        queue = []
        queuePosition = 0
    }
    
    public func next() -> PlaybackQueueEntry? {
        guard canGoNext else { return nil }
        queuePosition += 1
        return currentEntry
    }
    
    public func previous() -> PlaybackQueueEntry? {
        guard canGoPrevious else { return nil }
        queuePosition -= 1
        return currentEntry
    }
    
    public func append(_ entries: [PlaybackQueueEntry]) {
        let existingIDs = Set(queue.map(\.mediaID))
        let newEntries = entries.filter { !existingIDs.contains($0.mediaID) }
        queue.append(contentsOf: newEntries)
    }
}
