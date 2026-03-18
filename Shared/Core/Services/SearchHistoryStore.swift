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
        let normalizedPrefix = normalizedQuery(prefix)
        let descriptor = FetchDescriptor<SearchHistoryEntry>()
        let all = (try? context.fetch(descriptor)) ?? []
        let filtered = all.filter { entry in
            normalizedPrefix.isEmpty || entry.normalizedQuery.contains(normalizedPrefix)
        }

        return filtered
            .sorted { lhs, rhs in
                if lhs.successfulPlayCount != rhs.successfulPlayCount {
                    return lhs.successfulPlayCount > rhs.successfulPlayCount
                }
                if lhs.searchCount != rhs.searchCount {
                    return lhs.searchCount > rhs.searchCount
                }
                return lhs.lastSearchedAt > rhs.lastSearchedAt
            }
            .prefix(limit)
            .map { $0 }
    }

    private func fetchEntry(for normalized: String) -> SearchHistoryEntry? {
        let descriptor = FetchDescriptor<SearchHistoryEntry>()
        return (try? context.fetch(descriptor))?.first(where: { $0.normalizedQuery == normalized })
    }

    private func normalizedQuery(_ query: String) -> String {
        query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
