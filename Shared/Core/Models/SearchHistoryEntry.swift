import Foundation
import SwiftData

@Model
final class SearchHistoryEntry {
    var query: String
    var normalizedQuery: String
    var searchCount: Int
    var successfulPlayCount: Int
    var lastSearchedAt: Date

    init(query: String, normalizedQuery: String, searchCount: Int = 0, successfulPlayCount: Int = 0, lastSearchedAt: Date = .now) {
        self.query = query
        self.normalizedQuery = normalizedQuery
        self.searchCount = searchCount
        self.successfulPlayCount = successfulPlayCount
        self.lastSearchedAt = lastSearchedAt
    }
}
