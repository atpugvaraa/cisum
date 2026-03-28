import Foundation
import SwiftData

@Model
final class SearchCacheHintEntry {
    @Attribute(.unique) var cacheKey: String
    var normalizedQuery: String
    var scopeRawValue: String
    var topVideoIDsData: Data
    var updatedAt: Date
    var lastAccessedAt: Date

    init(
        cacheKey: String,
        normalizedQuery: String,
        scopeRawValue: String,
        topVideoIDsData: Data,
        updatedAt: Date = .now,
        lastAccessedAt: Date = .now
    ) {
        self.cacheKey = cacheKey
        self.normalizedQuery = normalizedQuery
        self.scopeRawValue = scopeRawValue
        self.topVideoIDsData = topVideoIDsData
        self.updatedAt = updatedAt
        self.lastAccessedAt = lastAccessedAt
    }
}
