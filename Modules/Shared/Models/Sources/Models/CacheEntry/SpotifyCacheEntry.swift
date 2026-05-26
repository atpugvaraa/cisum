import Foundation
import SwiftData

/// A generic cache entry for storing serialized Spotify SDK objects.
/// We store the raw JSON payload to avoid duplicating the massive SDK schema in SwiftData.
@Model
public final class SpotifyCacheEntry {
    @Attribute(.unique) public var key: String
    public var payload: Data
    public var updatedAt: Date

    public init(key: String, payload: Data, updatedAt: Date = Date()) {
        self.key = key
        self.payload = payload
        self.updatedAt = updatedAt
    }
}
