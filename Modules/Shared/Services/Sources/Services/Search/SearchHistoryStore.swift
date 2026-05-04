import Foundation
import SwiftData
import Models

@MainActor
public final class SearchHistoryStore {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func recordSearch(query: String) {
        let normalized = normalizedQuery(query)
        guard !normalized.isEmpty else { return }

        if let existing = fetchEntry(for: normalized) {
            existing.searchCount += 1
            existing.lastSearchedAt = .now
            existing.query = query
        } else {
            let entry = SearchHistoryEntry(
                query: query,
                normalizedQuery: normalized,
                searchCount: 1,
                successfulPlayCount: 0,
                lastSearchedAt: .now
            )
            context.insert(entry)
        }
        try? context.save()
    }

    public func recordSuccessfulPlay(query: String) {
        let normalized = normalizedQuery(query)
        guard !normalized.isEmpty else { return }

        if let existing = fetchEntry(for: normalized) {
            existing.successfulPlayCount += 1
            existing.lastSearchedAt = .now
            try? context.save()
        }
    }

    public func topCandidates(prefix: String, limit: Int = 20) -> [SearchHistoryEntry] {
        guard limit > 0 else { return [] }

        let normalizedPrefix = normalizedQuery(prefix)
        let descriptor: FetchDescriptor<SearchHistoryEntry>

        if normalizedPrefix.isEmpty {
            descriptor = FetchDescriptor<SearchHistoryEntry>(sortBy: rankingSortDescriptors)
        } else {
            descriptor = FetchDescriptor<SearchHistoryEntry>(
                predicate: #Predicate<SearchHistoryEntry> { entry in
                    entry.normalizedQuery.contains(normalizedPrefix)
                },
                sortBy: rankingSortDescriptors
            )
        }

        var limitedDescriptor = descriptor
        limitedDescriptor.fetchLimit = limit
        return (try? context.fetch(limitedDescriptor)) ?? []
    }

    private func fetchEntry(for normalized: String) -> SearchHistoryEntry? {
        var descriptor = FetchDescriptor<SearchHistoryEntry>(
            predicate: #Predicate { $0.normalizedQuery == normalized }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func normalizedQuery(_ query: String) -> String {
        query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var rankingSortDescriptors: [SortDescriptor<SearchHistoryEntry>] {
        [
            SortDescriptor(\SearchHistoryEntry.successfulPlayCount, order: .reverse),
            SortDescriptor(\SearchHistoryEntry.searchCount, order: .reverse),
            SortDescriptor(\SearchHistoryEntry.lastSearchedAt, order: .reverse)
        ]
    }
}
