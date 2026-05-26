import Foundation
import SwiftData

@Model
public final class QueueStateEntry {
    @Attribute(.unique) public var key: String

    // JSON-encoded array of QueueIdentitySnapshot
    public var itemsJSON: String?
    public var currentIndex: Int
    public var updatedAt: Date

    public init(key: String, itemsJSON: String? = nil, currentIndex: Int = 0, updatedAt: Date = .now) {
        self.key = key
        self.itemsJSON = itemsJSON
        self.currentIndex = currentIndex
        self.updatedAt = updatedAt
    }
}
