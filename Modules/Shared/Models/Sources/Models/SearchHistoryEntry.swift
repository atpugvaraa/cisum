//
//  SearchHistoryEntry.swift
//  Models
//
//  Created by Aarav Gupta on 29/04/26.
//

import Foundation
import SwiftData

@Model
public final class SearchHistoryEntry {
    public var query: String
    public var normalizedQuery: String
    public var searchCount: Int
    public var successfulPlayCount: Int
    public var lastSearchedAt: Date

    public init(query: String, normalizedQuery: String, searchCount: Int = 0, successfulPlayCount: Int = 0, lastSearchedAt: Date = .now) {
        self.query = query
        self.normalizedQuery = normalizedQuery
        self.searchCount = searchCount
        self.successfulPlayCount = successfulPlayCount
        self.lastSearchedAt = lastSearchedAt
    }
}
