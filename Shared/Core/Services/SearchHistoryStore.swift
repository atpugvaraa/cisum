import Foundation
import SwiftData

@MainActor
final class SearchHistoryStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func recordSearch(query: String) {
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

    func recordSuccessfulPlay(query: String) {
        let normalized = normalizedQuery(query)
        guard !normalized.isEmpty else { return }

        if let existing = fetchEntry(for: normalized) {
            existing.successfulPlayCount += 1
            existing.lastSearchedAt = .now
            try? context.save()
        }
    }

    func topCandidates(prefix: String, limit: Int = 20) -> [SearchHistoryEntry] {
        guard limit > 0 else { return [] }

        let normalizedPrefix = normalizedQuery(prefix)
        let batchFetchLimit = max(limit * 5, 50)

        var batchDescriptor = FetchDescriptor<SearchHistoryEntry>(
            sortBy: rankingSortDescriptors
        )
        batchDescriptor.fetchLimit = batchFetchLimit

        let rankedBatch = (try? context.fetch(batchDescriptor)) ?? []
        let filteredBatch = rankedBatch.filter { entry in
            normalizedPrefix.isEmpty || entry.normalizedQuery.contains(normalizedPrefix)
        }

        // Fast path: top-ranked batch already yielded enough matches.
        if filteredBatch.count >= limit || rankedBatch.count < batchFetchLimit {
            return Array(filteredBatch.prefix(limit))
        }

        // Fallback for rare prefixes that only appear in lower-ranked history.
        let allDescriptor = FetchDescriptor<SearchHistoryEntry>(sortBy: rankingSortDescriptors)
        let allEntries = (try? context.fetch(allDescriptor)) ?? []
        let filteredAll = allEntries.filter { entry in
            normalizedPrefix.isEmpty || entry.normalizedQuery.contains(normalizedPrefix)
        }

        return Array(filteredAll.prefix(limit))
    }

    private func fetchEntry(for normalized: String) -> SearchHistoryEntry? {
        let descriptor = FetchDescriptor<SearchHistoryEntry>()
        return (try? context.fetch(descriptor))?.first(where: { $0.normalizedQuery == normalized })
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
