//
//  SearchViewModel.swift
//  cisum
//
//  Created by Aarav Gupta on 03/12/25.
//

import SwiftUI
import YouTubeSDK

@Observable
@MainActor
class SearchViewModel {

    private enum CachePolicy {
        static let persistentHintMaxAge: TimeInterval = 60 * 60 * 24 * 7
    }

    private let youtube: YouTube
    private let settings: PrefetchSettings
    private let networkMonitor: NetworkPathMonitor
    private let historyStore: SearchHistoryStore?
    private let searchCacheHintStore: SearchCacheHintStore?

    init(
        youtube: YouTube = .shared,
        settings: PrefetchSettings = .shared,
        networkMonitor: NetworkPathMonitor = .shared,
        historyStore: SearchHistoryStore? = nil,
        searchCacheHintStore: SearchCacheHintStore? = nil
    ) {
        self.youtube = youtube
        self.settings = settings
        self.networkMonitor = networkMonitor
        self.historyStore = historyStore
        self.searchCacheHintStore = searchCacheHintStore
    }

    // Inputs
    var searchText: String = "" {
        didSet { performDebouncedSearch() }
    }
    var searchScope: SearchScope = .video {
        didSet { performDebouncedSearch() }
    }
    
    // Outputs
    var musicResults: [YouTubeMusicSong] = []
    var videoResults: [YouTubeSearchResult] = []
    var suggestions: [String] = []
    var state: SearchState = .idle
    
    // Internal
    private var searchTask: Task<Void, Never>?
    private var prefetchTask: Task<Void, Never>?
    private var suggestionTask: Task<Void, Never>?
    private var lastCompletedQuery: String?
    private var lastCompletedScope: SearchScope?
    private var suggestionCache: [String: [String]] = [:]
    private var lastSuggestionPrefetched: String?
    private var lastHintPrefetchedKey: String?
    private var videoContinuationToken: String?
    private var isLoadingMoreVideos = false
    private var videoContinuationBadResponseCount = 0
    private var lastPaginationTriggerAt: Date?
    private var lastPaginationTriggerToken: String?
    /// How many items from the end to start prefetching the next page.
    /// Increasing this reduces UI jumps at the cost of earlier network calls.
    private let videoPrefetchThreshold = 10
    private let paginationTriggerCooldown: TimeInterval = 0.25
    // Prefetch / cache
    private let metadataCache = VideoMetadataCache.shared
    private let searchCache = SearchResultsCache.shared

    var isVideoPaginationLoading: Bool {
        searchScope == .video && isLoadingMoreVideos && !videoResults.isEmpty
    }
    
    enum SearchScope {
        case music
        case video
    }
    
    enum SearchState {
        case idle
        case loading
        case error(String)
        case success
    }
    
    // MARK: - Actions
    
    public func performDebouncedSearch() {
        searchTask?.cancel() // 1. Cancel previous typing
        prefetchTask?.cancel()
        suggestionTask?.cancel()
        
        // 2. Clear results if empty
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.musicResults = []
            self.videoResults = []
            self.suggestions = []
            self.state = .idle
            self.lastHintPrefetchedKey = nil
            resetVideoPagination()
            return
        }

        suggestionTask = Task {
            try? await Task.sleep(for: .seconds(0.2))
            if Task.isCancelled { return }
            await fetchSuggestionsForCurrentQuery()
        }
        
        searchTask = Task {
            // 3. Debounce (Wait 0.5s)
            try? await Task.sleep(for: .seconds(0.35))
            if Task.isCancelled { return }

            await executeSearch()
        }
    }
    
    private func executeSearch() async {
        self.state = .loading
        
        do {
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let scope = searchScope
            if query.isEmpty {
                self.musicResults = []
                self.videoResults = []
                self.state = .idle
                return
            }

            prefetchFromPersistentHintsIfNeeded(for: query)

            if case .success = state,
               lastCompletedQuery == query,
               lastCompletedScope == scope {
                return
            }

            let effectiveQuery = effectiveSearchQuery(for: query, scope: scope)

            switch scope {
            case .music:
                // Serve cache if available (stale-while-revalidate)
                if let cached = searchCache.getMusicResults(for: query) {
                    self.musicResults = cached.results
                    self.state = .success
                    if cached.isStale {
                        // Refresh in background only when stale.
                        Task(priority: .utility) {
                            await self.refreshMusicResultsIfNeeded(for: query, scope: scope)
                        }
                    }
                } else {
                    let results = try await youtube.music.search(effectiveQuery)
                    self.musicResults = results
                    searchCache.setMusicResults(results, for: query)
                    self.state = .success
                }

                // Prefetch metadata for top results
                historyStore?.recordSearch(query: query)
                let ids = Array(self.musicResults.prefix(currentPrefetchCount).compactMap { $0.videoId })
                prefetchTopResultIDs(ids)
                searchCacheHintStore?.recordMusicResults(query: query, results: self.musicResults)

            case .video:
                // SDK returns a continuation - map to YouTubeSearchResult for UI
                resetVideoPagination()
                if let cached = searchCache.getVideoResults(for: query) {
                    // If cached, show and refresh in background
                    self.videoResults = cached.results
                    self.state = .success
                    if cached.isStale {
                        Task(priority: .utility) {
                            await self.refreshVideoResultsIfNeeded(for: query, scope: scope)
                        }
                    }
                } else {
                    let cont = try await youtube.main.search(effectiveQuery)
                    updateVideoResults(with: cont, appending: false)
                    // Cache the mapped video results
                    let mapped = mapSearchResults(from: cont.items)
                    searchCache.setVideoResults(mapped, for: query)
                    self.state = .success
                }

                // Prefetch metadata for top video results
                historyStore?.recordSearch(query: query)
                let vidIDs = Array(self.videoResults.compactMap { item -> String? in
                    if case .video(let v) = item { return v.id }
                    return nil
                }.prefix(currentPrefetchCount))
                prefetchTopResultIDs(vidIDs)
                searchCacheHintStore?.recordVideoResults(query: query, results: self.videoResults)
            }

            self.lastCompletedQuery = query
            self.lastCompletedScope = scope
            
        } catch {
            if !Task.isCancelled {
                self.state = .error("\(error.localizedDescription)")
            }
        }
    }

    public func applySuggestion(_ suggestion: String) {
        let cleaned = suggestion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        searchTask?.cancel()
        searchText = cleaned
        historyStore?.recordSearch(query: cleaned)
        Task { await executeSearch() }
    }

    public func recordSuccessfulPlayFromCurrentQuery() {
        historyStore?.recordSuccessfulPlay(query: searchText)
    }

    // MARK: - Caching Helpers

    private func refreshMusicResultsIfNeeded(for query: String) async {
        await refreshMusicResultsIfNeeded(for: query, scope: searchScope)
    }

    private func refreshMusicResultsIfNeeded(for query: String, scope: SearchScope) async {
        do {
            let effectiveQuery = effectiveSearchQuery(for: query, scope: scope)
            let results = try await youtube.music.search(effectiveQuery)
            searchCache.setMusicResults(results, for: query)
            searchCacheHintStore?.recordMusicResults(query: query, results: results)
            await MainActor.run {
                if self.searchText == query, self.searchScope == scope { self.musicResults = results }
            }
        } catch {
            // ignore background refresh errors
        }
    }

    private func refreshVideoResultsIfNeeded(for query: String) async {
        await refreshVideoResultsIfNeeded(for: query, scope: searchScope)
    }

    private func refreshVideoResultsIfNeeded(for query: String, scope: SearchScope) async {
        do {
            let effectiveQuery = effectiveSearchQuery(for: query, scope: scope)
            let cont = try await youtube.main.search(effectiveQuery)
            let mapped = mapSearchResults(from: cont.items)
            searchCache.setVideoResults(mapped, for: query)
            searchCacheHintStore?.recordVideoResults(query: query, results: mapped)
            await MainActor.run {
                if self.searchText == query, self.searchScope == scope { self.videoResults = mapped }
            }
        } catch {
            // ignore background refresh errors
        }
    }

    // Prefetch metadata and resolved stream urls for top items.
    private func prefetchTopResultIDs(_ ids: [String]) {
        prefetchTask?.cancel()
        guard !ids.isEmpty else { return }
        let youtube = self.youtube
        let mode = effectivePrefetchMode
        let concurrency = currentPrefetchConcurrency
        let metricsEnabled = settings.metricsEnabled
        prefetchTask = Task(priority: .utility) {
            await self.metadataCache.prefetch(
                ids: ids,
                maxConcurrent: concurrency,
                mode: mode,
                metricsEnabled: metricsEnabled
            ) { id in
                try await youtube.main.video(id: id)
            }
        }
    }

    // Public helper to prefetch a single id (used by row onAppear)
    public func prefetchIfNeeded(id: String) {
        guard !id.isEmpty else { return }
        let youtube = self.youtube
        let mode = effectivePrefetchMode
        let metricsEnabled = settings.metricsEnabled
        Task(priority: .utility) {
            await self.metadataCache.prefetch(
                ids: [id],
                maxConcurrent: 1,
                mode: mode,
                metricsEnabled: metricsEnabled
            ) { key in
                try await youtube.main.video(id: key)
            }
        }
    }

    private func fetchSuggestionsForCurrentQuery() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            suggestions = []
            return
        }

        let cacheKey = "\(searchScope)-\(query.lowercased())"
        if let cached = suggestionCache[cacheKey] {
            suggestions = cached
            if settings.suggestionPipelineEnabled {
                await prefetchFromTopSuggestionIfNeeded(cached)
            }
            return
        }

        do {
            let remote: [String]
            switch searchScope {
            case .music:
                remote = try await youtube.music.getSearchSuggestions(query: query)
            case .video:
                remote = try await youtube.main.getSearchSuggestions(query: effectiveSearchQuery(for: query, scope: .video))
            }

            let local = historyStore?.topCandidates(prefix: query, limit: 20) ?? []
            var candidates: [SuggestionCandidate] = []

            candidates.append(contentsOf: remote.map {
                SuggestionCandidate(
                    text: $0,
                    frequency: 0,
                    successfulPlays: 0,
                    recency: .distantPast,
                    sourceBoost: 0.6
                )
            })

            candidates.append(contentsOf: local.map {
                SuggestionCandidate(
                    text: $0.query,
                    frequency: $0.searchCount,
                    successfulPlays: $0.successfulPlayCount,
                    recency: $0.lastSearchedAt,
                    sourceBoost: 1.0
                )
            })

            let ranked = SuggestionRanker.rank(input: query, candidates: candidates, limit: 8)
            suggestionCache[cacheKey] = ranked
            suggestions = ranked

            if settings.suggestionPipelineEnabled {
                await prefetchFromTopSuggestionIfNeeded(ranked)
            }
        } catch {
            // Keep UI responsive even if suggestions endpoint fails.
            suggestions = (historyStore?.topCandidates(prefix: query, limit: 8) ?? []).map { $0.query }
        }
    }

    private func prefetchFromTopSuggestionIfNeeded(_ rankedSuggestions: [String]) async {
        guard let top = rankedSuggestions.first else { return }
        guard top != lastSuggestionPrefetched else { return }
        lastSuggestionPrefetched = top

        let normalizedTop = top.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTop.isEmpty else { return }

        let scope = searchScope
        let mode = effectivePrefetchMode
        let metricsEnabled = settings.metricsEnabled
        let youtube = self.youtube

        do {
            let ids: [String]
            switch scope {
            case .music:
                let results: [YouTubeMusicSong]
                if let cached = searchCache.getMusicResults(for: normalizedTop), !cached.isStale {
                    results = cached.results
                } else {
                    results = try await youtube.music.search(effectiveSearchQuery(for: normalizedTop, scope: scope))
                    searchCache.setMusicResults(results, for: normalizedTop)
                    searchCacheHintStore?.recordMusicResults(query: normalizedTop, results: results)
                }
                ids = Array(results.prefix(3).map { $0.videoId })

            case .video:
                let results: [YouTubeSearchResult]
                if let cached = searchCache.getVideoResults(for: normalizedTop), !cached.isStale {
                    results = cached.results
                } else {
                    let continuation = try await youtube.main.search(effectiveSearchQuery(for: normalizedTop, scope: scope))
                    let mapped = mapSearchResults(from: continuation.items)
                    searchCache.setVideoResults(mapped, for: normalizedTop)
                    searchCacheHintStore?.recordVideoResults(query: normalizedTop, results: mapped)
                    results = mapped
                }
                ids = Array(results.compactMap { item -> String? in
                    if case .video(let v) = item { return v.id }
                    return nil
                }.prefix(3))
            }

            await metadataCache.prefetch(
                ids: ids,
                maxConcurrent: min(3, currentPrefetchConcurrency),
                mode: mode,
                metricsEnabled: metricsEnabled
            ) { id in
                try await youtube.main.video(id: id)
            }
        } catch {
            // Best effort prefetch.
        }
    }

    private var currentPrefetchCount: Int {
        guard settings.adaptivePrefetchEnabled else {
            return max(1, settings.wifiPrefetchCount)
        }
        if networkMonitor.interface == .cellular || networkMonitor.isExpensive || networkMonitor.isConstrained {
            return max(1, settings.cellularPrefetchCount)
        }
        return max(1, settings.wifiPrefetchCount)
    }

    private var currentPrefetchConcurrency: Int {
        guard settings.adaptivePrefetchEnabled else {
            return max(1, settings.wifiPrefetchConcurrency)
        }
        if networkMonitor.interface == .cellular || networkMonitor.isExpensive || networkMonitor.isConstrained {
            return max(1, settings.cellularPrefetchConcurrency)
        }
        return max(1, settings.wifiPrefetchConcurrency)
    }

    private var effectivePrefetchMode: PrefetchModeOverride {
        if settings.prefetchModeOverride != .auto {
            return settings.prefetchModeOverride
        }
        if networkMonitor.interface == .wifi, !networkMonitor.isExpensive, !networkMonitor.isConstrained {
            return .aggressiveWarmup
        }
        return .metadataOnly
    }

    private func prefetchFromPersistentHintsIfNeeded(for query: String) {
        guard let searchCacheHintStore else { return }

        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return }

        let key = "\(searchScope)-\(normalized)"
        guard key != lastHintPrefetchedKey else { return }

        let scope: SearchCacheHintStore.Scope = {
            switch searchScope {
            case .music: return .music
            case .video: return .video
            }
        }()

        let ids = searchCacheHintStore.cachedTopVideoIDs(
            for: normalized,
            scope: scope,
            maxAge: CachePolicy.persistentHintMaxAge
        )
        guard !ids.isEmpty else { return }

        lastHintPrefetchedKey = key

        let youtube = self.youtube
        let mode = effectivePrefetchMode
        let metricsEnabled = settings.metricsEnabled
        let concurrency = min(4, currentPrefetchConcurrency)

        Task(priority: .utility) {
            await self.metadataCache.prefetch(
                ids: Array(ids.prefix(6)),
                maxConcurrent: concurrency,
                mode: mode,
                metricsEnabled: metricsEnabled
            ) { id in
                try await youtube.main.video(id: id)
            }
        }
    }

    func loadMoreVideosIfNeeded(for item: YouTubeSearchResult) {
        guard searchScope == .video else { return }
        // Trigger when the appearing item is within `videoPrefetchThreshold`
        // items from the end so we begin loading earlier and reduce jumps.
        guard let idx = videoResults.firstIndex(where: { $0.id == item.id }) else { return }
        let shouldTrigger = idx >= (videoResults.count - videoPrefetchThreshold)
        guard shouldTrigger else { return }
        guard let token = videoContinuationToken, !token.isEmpty else { return }
        guard !isLoadingMoreVideos else { return }

        if let lastTime = lastPaginationTriggerAt,
           lastPaginationTriggerToken == token,
           Date().timeIntervalSince(lastTime) < paginationTriggerCooldown {
            return
        }

        lastPaginationTriggerAt = Date()
        lastPaginationTriggerToken = token

        Task {
            await loadMoreVideos()
        }
    }

    private func loadMoreVideos() async {
        guard let token = videoContinuationToken, !token.isEmpty else { return }
        guard !isLoadingMoreVideos else { return }

        isLoadingMoreVideos = true
        defer { isLoadingMoreVideos = false }

        do {
            let continuation = try await youtube.main.fetchContinuation(token: token)
            updateVideoResults(with: continuation, appending: true)
            // Reset bad-response counter on successful continuation
            videoContinuationBadResponseCount = 0
        } catch {
            if !Task.isCancelled {
                // If the error looks like a repeated bad server response (HTTP 400
                // or NSURLErrorBadServerResponse -1011), increment a counter and
                // defensively clear the continuation token after a couple attempts
                // to avoid spamming failing requests while the user scrolls.
                if let ns = error as NSError? {
                    if ns.code == 400 || (ns.domain == NSURLErrorDomain && ns.code == -1011) {
                        videoContinuationBadResponseCount += 1
                        if videoContinuationBadResponseCount >= 2 {
                            videoContinuationToken = nil
                            state = .error("Pagination temporarily disabled due to server responses.")
                        }
                    } else {
                        videoContinuationBadResponseCount = 0
                    }
                } else {
                    videoContinuationBadResponseCount = 0
                }
            }
        }
    }

    private func updateVideoResults(with continuation: YouTubeContinuation<YouTubeItem>, appending: Bool) {
        let mapped = mapSearchResults(from: continuation.items)
        if appending {
            self.videoResults.append(contentsOf: mapped)
        } else {
            // Initial load replace without animation to avoid strange layout jumps.
            self.videoResults = mapped
        }

        self.videoContinuationToken = continuation.continuationToken
        // Re-arm trigger protection for the next token progression.
        self.lastPaginationTriggerToken = continuation.continuationToken
        // Successful parse/append — reset any bad-response tracking
        videoContinuationBadResponseCount = 0
    }

    private func mapSearchResults(from items: [YouTubeItem]) -> [YouTubeSearchResult] {
        return items.compactMap { item in
            switch item {
            case .video(let v):
                guard shouldKeepVideoResult(v) else { return nil }
                return .video(v)
            case .channel(let c): return .channel(c)
            case .playlist(let p): return .playlist(p)
            default: return nil
            }
        }
    }

    private func effectiveSearchQuery(for query: String, scope: SearchScope) -> String {
        switch scope {
        case .music:
            return query
        case .video:
            return musicVideoSearchQuery(query)
        }
    }

    private func shouldKeepVideoResult(_ video: YouTubeVideo) -> Bool {
        let title = normalizedMusicDisplayTitle(video.title, artist: video.author).lowercased()
        let author = normalizedMusicDisplayArtist(video.author, title: video.title).lowercased()

        let blockedMarkers = [
            "#shorts",
            "/shorts/",
            "shorts",
            "reaction",
            "review",
            "podcast",
            "interview",
            "tutorial",
            "gameplay",
            "gaming"
        ]

        return !blockedMarkers.contains { marker in
            title.contains(marker) || author.contains(marker)
        }
    }

    private func resetVideoPagination() {
        videoContinuationToken = nil
        isLoadingMoreVideos = false
        videoContinuationBadResponseCount = 0
        lastPaginationTriggerAt = nil
        lastPaginationTriggerToken = nil
    }
}
