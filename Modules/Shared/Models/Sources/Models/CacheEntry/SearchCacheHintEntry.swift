//
//  SearchCacheHintEntry.swift
//  Models
//
//  Created by Aarav Gupta on 29/04/26.
//

import Foundation
import SwiftData

@Model
public final class SearchCacheHintEntry {
    @Attribute(.unique) public var cacheKey: String
    public var normalizedQuery: String
    public var scopeRawValue: String
    public var topVideoIDsData: Data
    public var updatedAt: Date
    public var lastAccessedAt: Date

    public init(
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
