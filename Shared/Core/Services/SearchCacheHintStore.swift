import Foundation
import SwiftData
import YouTubeSDK

@MainActor
final class SearchCacheHintStore {
    enum Scope: String {
        case music
        case video
    }

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func cachedTopVideoIDs(
        for query: String,
        scope: Scope,
        maxAge: TimeInterval
    ) -> [String] {
        let normalized = normalizedQuery(query)
        guard !normalized.isEmpty,
              let entry = fetchEntry(for: normalized, scope: scope),
              Date().timeIntervalSince(entry.updatedAt) <= maxAge,
              let ids = decodeVideoIDs(from: entry.topVideoIDsData),
              !ids.isEmpty else {
            return []
        }

        entry.lastAccessedAt = .now
        saveContext()
        return ids
    }

    func recordMusicResults(
        query: String,
        results: [YouTubeMusicSong],
        topLimit: Int = 8
    ) {
        let ids = results
            .prefix(max(1, topLimit))
            .map(\.videoId)

        record(
            query: query,
            scope: .music,
            topVideoIDs: ids
        )
    }

    func recordVideoResults(
        query: String,
        results: [YouTubeSearchResult],
        topLimit: Int = 8
    ) {
        let ids = results.compactMap { result -> String? in
            if case .video(let video) = result {
                return video.id
            }
            return nil
        }
        .prefix(max(1, topLimit))

        record(
            query: query,
            scope: .video,
            topVideoIDs: Array(ids)
        )
    }

    func performMaintenance(
        maxAge: TimeInterval = 60 * 60 * 24 * 14,
        maxEntries: Int = 800
    ) {
        let entries = allEntries()
        let now = Date()

        for entry in entries {
            if now.timeIntervalSince(entry.updatedAt) > maxAge {
                context.delete(entry)
            }
        }

        if maxEntries > 0 {
            let sorted = allEntries().sorted { lhs, rhs in
                lhs.lastAccessedAt > rhs.lastAccessedAt
            }

            if sorted.count > maxEntries {
                for entry in sorted.dropFirst(maxEntries) {
                    context.delete(entry)
                }
            }
        }

        saveContext()
    }

    private func record(query: String, scope: Scope, topVideoIDs: [String]) {
        let normalized = normalizedQuery(query)
        guard !normalized.isEmpty else { return }

        let uniqueIDs = deduplicatedIDs(from: topVideoIDs)
        guard !uniqueIDs.isEmpty,
              let encoded = encodeVideoIDs(uniqueIDs) else {
            return
        }

        let entry = entryForWrite(normalizedQuery: normalized, scope: scope)
        entry.topVideoIDsData = encoded
        entry.updatedAt = .now
        entry.lastAccessedAt = .now
        saveContext()
    }

    private func entryForWrite(normalizedQuery: String, scope: Scope) -> SearchCacheHintEntry {
        if let existing = fetchEntry(for: normalizedQuery, scope: scope) {
            return existing
        }

        let created = SearchCacheHintEntry(
            cacheKey: cacheKey(for: normalizedQuery, scope: scope),
            normalizedQuery: normalizedQuery,
            scopeRawValue: scope.rawValue,
            topVideoIDsData: Data()
        )
        context.insert(created)
        return created
    }

    private func fetchEntry(for normalizedQuery: String, scope: Scope) -> SearchCacheHintEntry? {
        let key = cacheKey(for: normalizedQuery, scope: scope)
        var descriptor = FetchDescriptor<SearchCacheHintEntry>(
            predicate: #Predicate { $0.cacheKey == key }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func allEntries() -> [SearchCacheHintEntry] {
        let descriptor = FetchDescriptor<SearchCacheHintEntry>()
        return (try? context.fetch(descriptor)) ?? []
    }

    private func normalizedQuery(_ query: String) -> String {
        query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func cacheKey(for normalizedQuery: String, scope: Scope) -> String {
        "\(scope.rawValue)::\(normalizedQuery)"
    }

    private func deduplicatedIDs(from ids: [String]) -> [String] {
        var seen: Set<String> = []
        var deduplicated: [String] = []

        for id in ids {
            let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if seen.contains(trimmed) { continue }
            seen.insert(trimmed)
            deduplicated.append(trimmed)
        }

        return deduplicated
    }

    private func encodeVideoIDs(_ ids: [String]) -> Data? {
        try? JSONEncoder().encode(ids)
    }

    private func decodeVideoIDs(from data: Data) -> [String]? {
        try? JSONDecoder().decode([String].self, from: data)
    }

    private func saveContext() {
        try? context.save()
    }
}
