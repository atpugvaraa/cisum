import SwiftUI
import YouTubeSDK
import Observation
import Models
import Utilities
import Services

#if canImport(SpotifySDK)
import SpotifySDK
#endif

@Observable
@MainActor
public class SearchViewModel: SearchViewModelInterface {

    private enum CachePolicy {
        nonisolated static let persistentHintMaxAge: TimeInterval = 60 * 60 * 24 * 7
    }

    private enum UnifiedTopResultsPolicy {
        nonisolated static let limit: Int = 5
        // Hidden providers only; Spotify uses dedicated sections
        nonisolated static let services: [FederatedService] = [.youtubeMusic, .youtube]
        nonisolated static let maxPerService: [FederatedService: Int] = [
            .youtubeMusic: 3,
            .youtube: 3
        ]
    }

    private enum YouMightLikePolicy {
        nonisolated static let limit: Int = 8
        nonisolated static let services: [FederatedService] = [.youtubeMusic, .youtube]
    }

    // Fallback resolution order for Spotify items: YouTube Music → YouTube
    private enum SpotifyFallbackResolutionPolicy {
        nonisolated static let order: [FederatedService] = [.youtubeMusic, .youtube]
    }

    private let youtube: YouTube
    private let settings: PrefetchSettings
    private let networkMonitor: NetworkPathMonitor
    private let historyStore: Services.SearchHistoryStore
    private let searchCacheHintStore: Services.SearchCacheHintStore
    private let streamingProviderSettings: StreamingProviderSettings
    private let centralMediaStore: CentralMediaStore?
    private let metadataCache: any VideoMetadataCaching
    private let searchCache: any SearchResultsCaching

    public init(
        youtube: YouTube,
        settings: PrefetchSettings,
        networkMonitor: NetworkPathMonitor,
        historyStore: Services.SearchHistoryStore,
        searchCacheHintStore: Services.SearchCacheHintStore,
        streamingProviderSettings: StreamingProviderSettings,
        centralMediaStore: CentralMediaStore? = nil,
        metadataCache: any VideoMetadataCaching,
        searchCache: any SearchResultsCaching
    ) {
        self.youtube = youtube
        self.settings = settings
        self.networkMonitor = networkMonitor
        self.historyStore = historyStore
        self.searchCacheHintStore = searchCacheHintStore
        self.streamingProviderSettings = streamingProviderSettings
        self.centralMediaStore = centralMediaStore
        self.metadataCache = metadataCache
        self.searchCache = searchCache
    }

    // Inputs
    public var searchText: String = "" {
        didSet { performDebouncedSearch() }
    }
    public var searchScope: SearchScope = .video {
        didSet { performDebouncedSearch() }
    }
    
    // Outputs
    public var musicResults: [YouTubeMusicSong] = []
    public var videoResults: [YouTubeSearchResult] = []
    public var federatedSections: [FederatedSearchSection] = FederatedSearchSection.defaultSections
    public var unifiedTopResults: [FederatedSearchItem] = []
    public var youMightLikeResults: [FederatedSearchItem] = []
    public var suggestions: [String] = []
    public var state: SearchState = .idle

    // Spotify visible sections
    public var spotifyTrackResults: [FederatedSearchItem] = []
    public var spotifyArtistResults: [FederatedSearchItem] = []
    public var spotifyPlaylistResults: [FederatedSearchItem] = []

    // Maps spotify item ID → best matching hidden-provider item
    // Populated asynchronously after hidden providers complete.
    public private(set) var hiddenFallbackMap: [String: FederatedSearchItem] = [:]
    
    // Internal
    private var searchTask: Task<Void, Never>?
    private var prefetchTask: Task<Void, Never>?
    private var suggestionTask: Task<Void, Never>?
    private var lastCompletedQuery: String?
    private var suggestionCache: [String: [String]] = [:]
    private var lastSuggestionPrefetched: String?
    private var lastHintPrefetchedKey: String?
    private var videoContinuationToken: String?
    private var isLoadingMoreVideos = false
    private var videoContinuationBadResponseCount = 0
    private var lastPaginationTriggerAt: Date?
    private var lastPaginationTriggerToken: String?
    private var inlinePrefetchedVideoIDs: Set<String> = []
    private var inlinePrefetchPendingIDs: Set<String> = []
    private var inlinePrefetchDrainTask: Task<Void, Never>?
    private let inlinePrefetchCoalesceWindow: Duration = .milliseconds(80)
    /// How many items from the end to start prefetching the next page.
    /// Increasing this reduces UI jumps at the cost of earlier network calls.
    private let videoPrefetchThreshold = 10
    private let paginationTriggerCooldown: TimeInterval = 0.25

    public var isVideoPaginationLoading: Bool {
        searchScope == .video && isLoadingMoreVideos && !videoResults.isEmpty
    }
    
    // MARK: - Actions
    
    public func performDebouncedSearch() {
        Utilities.Logger.log("SearchViewModel: performDebouncedSearch called with text: '\(searchText)'")
        searchTask?.cancel() // 1. Cancel previous typing
        prefetchTask?.cancel()
        suggestionTask?.cancel()
        inlinePrefetchDrainTask?.cancel()
        inlinePrefetchDrainTask = nil
        inlinePrefetchPendingIDs.removeAll(keepingCapacity: true)
        
        // 2. Clear results if empty
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Utilities.Logger.log("SearchViewModel: Text is empty, clearing results.")
            clearAllResults()
            self.suggestions = []
            self.state = .idle
            return
        }

        suggestionTask = Task {
            try? await Task.sleep(for: .seconds(0.4))
            if Task.isCancelled { return }
            await fetchSuggestionsForCurrentQuery()
        }
        
        searchTask = Task {
            // 3. Debounce (Wait 0.5s)
            try? await Task.sleep(for: .seconds(0.6))
            if Task.isCancelled { return }

            Utilities.Logger.log("SearchViewModel: Debounce finished, executing search for '\(searchText)'")
            await executeSearch()
        }
    }
    
    private func executeSearch() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            clearAllResults()
            self.state = .idle
            return
        }

        if case .success = state,
           lastCompletedQuery == query {
            Utilities.Logger.log("SearchViewModel: Query '\(query)' matches last completed query, skipping.")
            return
        }

        Utilities.Logger.log("SearchViewModel: Starting simplified sequential search for '\(query)'")
        self.state = .loading

        resetFederatedSections(state: .loading)
        clearSpotifySections()
        unifiedTopResults = []
        youMightLikeResults = []
        hiddenFallbackMap = [:]
        historyStore.recordSearch(query: query)

        let effectiveVideoQuery = effectiveSearchQuery(for: query, scope: .video)

        // 1. Spotify (Primary UI feed)
        Utilities.Logger.log("SearchViewModel: Fetching Spotify results...")
        let spotifyResult = await self.fetchSpotifySectionItems(query: query)
        self.applySpotifySearchResult(spotifyResult)
        self.refreshUnifiedResults(for: query)

        // 2. YouTube Music
        Utilities.Logger.log("SearchViewModel: Fetching YouTube Music results...")
        let ytMusicResult = await self.fetchYouTubeMusicSectionItems(query: query, updateUI: true)
        self.applyFederatedSearchResult(ytMusicResult, for: .youtubeMusic)
        self.refreshUnifiedResults(for: query)

        // 3. YouTube (Video)
        Utilities.Logger.log("SearchViewModel: Fetching YouTube Video results...")
        let ytVideoResult = await self.fetchYouTubeSectionItems(query: effectiveVideoQuery, updateUI: true)
        self.applyFederatedSearchResult(ytVideoResult, for: .youtube)
        self.refreshUnifiedResults(for: query)

        self.state = .success
        self.lastCompletedQuery = query
    }

    private func refreshUnifiedResults(for query: String) {
        buildHiddenFallbackMap(for: query)
        
        let sections = self.federatedSections
        let currentSpotifyTrackResults = self.spotifyTrackResults
        let currentSpotifyArtistResults = self.spotifyArtistResults
        let currentSpotifyPlaylistResults = self.spotifyPlaylistResults
        
        Task {
            let topResults = await self.performUnifiedRanking(for: query, sections: sections)
            let excludedIDs = Set(topResults.map(\.id))
            let likeResults = await self.performYouMightLikeRanking(for: query, sections: sections, anchorResults: topResults, excludingIDs: excludedIDs)
            
            await MainActor.run {
                // Verify query still matches to avoid stale results
                guard query == self.searchText.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
                
                self.unifiedTopResults = topResults
                self.youMightLikeResults = likeResults
                
                let hasResults = !currentSpotifyTrackResults.isEmpty
                    || !currentSpotifyArtistResults.isEmpty
                    || !currentSpotifyPlaylistResults.isEmpty
                    || !topResults.isEmpty
                    || !likeResults.isEmpty
                
                if hasResults && self.state == .loading {
                    self.state = .success
                }
            }
        }
    }

    nonisolated private func performUnifiedRanking(for query: String, sections: [FederatedSearchSection]) async -> [FederatedSearchItem] {
        return buildUnifiedTopResults(for: query, in: sections)
    }

    nonisolated private func performYouMightLikeRanking(for query: String, sections: [FederatedSearchSection], anchorResults: [FederatedSearchItem], excludingIDs: Set<String>) async -> [FederatedSearchItem] {
        return buildYouMightLikeResults(for: query, in: sections, anchorResults: anchorResults, excludingIDs: excludingIDs)
    }

    private func clearAllResults() {
        musicResults = []
        videoResults = []
        federatedSections = FederatedSearchSection.defaultSections
        unifiedTopResults = []
        youMightLikeResults = []
        clearSpotifySections()
        hiddenFallbackMap = [:]
        lastHintPrefetchedKey = nil
        inlinePrefetchedVideoIDs.removeAll(keepingCapacity: true)
        resetVideoPagination()
    }

    private func clearSpotifySections() {
        spotifyTrackResults = []
        spotifyArtistResults = []
        spotifyPlaylistResults = []
    }

    private func applySpotifySearchResult(_ result: Result<SpotifySearchItems, Error>) {
        switch result {
        case .success(let items):
            spotifyTrackResults = items.tracks
            spotifyArtistResults = items.artists
            spotifyPlaylistResults = items.playlists
        case .failure:
            clearSpotifySections()
        }
    }

    /// Builds a map of spotifyItemID → best hidden-provider match by title+artist similarity.
    private func buildHiddenFallbackMap(for query: String) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let hiddenItems = SpotifyFallbackResolutionPolicy.order.flatMap { items(for: $0) }
        guard !hiddenItems.isEmpty else { return }

        for spotifyItem in spotifyTrackResults {
            let spotifyTitle = normalizedRankingText(spotifyItem.title)
            let spotifyArtist = normalizedRankingText(primaryArtistName(from: spotifyItem.subtitle))

            let bestMatch = hiddenItems
                .filter { $0.isPlayable }
                .map { hiddenItem -> (item: FederatedSearchItem, score: Double) in
                    let hiddenTitle = normalizedRankingText(hiddenItem.title)
                    let hiddenArtist = normalizedRankingText(primaryArtistName(from: hiddenItem.subtitle))
                    let titleSim = tokenOverlapScore(spotifyTitle, hiddenTitle)
                    let artistSim = tokenOverlapScore(spotifyArtist, hiddenArtist)
                    let priority = providerPriority(for: hiddenItem.service)
                    let serviceBonus = Double(3 - priority) * 0.02
                    return (hiddenItem, (0.6 * titleSim) + (0.4 * artistSim) + serviceBonus)
                }
                .filter { $0.score > 0.4 }
                .max(by: { $0.score < $1.score })
                .map { $0.item }

            if let match = bestMatch {
                hiddenFallbackMap[spotifyItem.id] = match
            }
        }
    }

    public func items(for service: FederatedService) -> [FederatedSearchItem] {
        federatedSections.first(where: { $0.service == service })?.items ?? []
    }

    public func sectionState(for service: FederatedService) -> FederatedSectionState {
        federatedSections.first(where: { $0.service == service })?.state ?? .idle
    }

    public func resolveExternalStream(for item: FederatedSearchItem) async throws -> ExternalStreamPayload? {
        switch item.payload {
        case .youtubeVideo(let video):
            return try await resolveYouTubeExternalStream(
                for: video.id,
                title: video.title,
                artist: video.author,
                artworkURL: video.thumbnailURL.flatMap { URL(string: $0) }
            )
            
        case .youtubeMusic(let song):
            return try await resolveYouTubeExternalStream(
                for: song.videoId,
                title: song.title,
                artist: song.artists.first ?? "Unknown",
                artworkURL: song.thumbnailURL
            )

        case .spotify:
            return try await resolveSpotifyViaHiddenFallback(for: item)
        case .spotifyArtist(_), .spotifyPlaylist(_):
            return nil
        }
    }

    private func resolveYouTubeExternalStream(for videoID: String, title: String, artist: String, artworkURL: URL?) async throws -> ExternalStreamPayload {
        let resolver = await PlaybackURLResolver.sharedInstance()
        let url = try await resolver.resolve(videoID: videoID)
        
        let ext = url.pathExtension.lowercased()
        let codec = ext == "m3u8" ? "hls" : "mp4"
        let quality = codec == "hls" ? "Adaptive" : "Standard"
        return ExternalStreamPayload(
            mediaID: "youtube-\(videoID)",
            streamURL: url,
            title: title,
            artist: artist,
            artworkURL: artworkURL,
            service: .youtube,
            qualityLabel: quality,
            codecLabel: codec
        )
    }

    /// Resolves a playable stream for a Spotify item by matching against hidden providers.
    /// Resolution order: YouTube Music → YouTube.
    private func resolveSpotifyViaHiddenFallback(for spotifyItem: FederatedSearchItem) async throws -> ExternalStreamPayload? {
        let spotifyTitle = spotifyItem.title
        let spotifyArtist = primaryArtistName(from: spotifyItem.subtitle)
        let spotifyDuration = spotifyItem.durationSeconds
        
        // Try local visible results next (fast path)
        let hiddenItems = SpotifyFallbackResolutionPolicy.order.flatMap { items(for: $0) }
        
        let bestLocal = await Task.detached {
            self.findBestSpotifyFallbackMatch(
                for: spotifyTitle,
                artist: spotifyArtist,
                durationSeconds: spotifyDuration,
                in: hiddenItems
            )
        }.value
        
        if let bestLocal, bestLocal.score >= 0.72 {
            if let payload = try await resolveExternalStream(for: bestLocal.item) {
                rememberSpotifyPlaybackTarget(for: spotifyItem, payload: payload)
                return payload
            }
        }

        // 3. Try on-demand search (slow path)
        if let onDemandFallback = await resolveSpotifyOnDemandYouTubeFallback(
            title: spotifyTitle,
            artist: spotifyArtist,
            durationSeconds: spotifyDuration,
            artworkURL: spotifyItem.artworkURL
        ) {
            rememberSpotifyPlaybackTarget(for: spotifyItem, payload: onDemandFallback)
            return onDemandFallback
        }

        throw FederatedSearchError.noPlayableStream(
            "No YouTube-backed stream could be found for \"\(spotifyTitle)\"."
        )
    }

    private func rememberSpotifyPlaybackTarget(for spotifyItem: FederatedSearchItem, payload: ExternalStreamPayload) {
        guard let spotifyTrackID = spotifyTrackID(from: spotifyItem) else { return }
        guard let canonicalProvider = canonicalProvider(for: payload.service) else { return }

        centralMediaStore?.cacheSpotifyPlaybackTarget(
            spotifyTrackID: spotifyTrackID,
            mediaID: payload.mediaID,
            provider: canonicalProvider
        )
    }

    private func spotifyTrackID(from item: FederatedSearchItem) -> String? {
        guard item.id.hasPrefix("spotify-") else { return nil }
        return String(item.id.dropFirst("spotify-".count))
    }

    private func canonicalProvider(for service: FederatedService) -> MediaProvider? {
        switch service {
        case .youtube:
            return .youtube
        case .youtubeMusic:
            return .youtubeMusic
        case .spotify:
            return .spotify
        }
    }

    private func resolveSpotifyOnDemandYouTubeFallback(
        title: String,
        artist: String,
        durationSeconds: TimeInterval?,
        artworkURL: URL?
    ) async -> ExternalStreamPayload? {
        let titleValue = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let artistValue = artist.trimmingCharacters(in: .whitespacesAndNewlines)

        let query = [artistValue, titleValue].filter { !$0.isEmpty }.joined(separator: " ")
        guard !query.isEmpty else { return nil }

        Utilities.Logger.log("SearchViewModel: Resolving Spotify fallback in parallel for '\(query)'...")

        return await withTaskGroup(of: ExternalStreamPayload?.self) { group in
            // 1. YouTube Music Task
            group.addTask {
                try? Task.checkCancellation()
                let result = await self.fetchYouTubeMusicSectionItems(query: query, updateUI: false)
                if case .success(let items) = result {
                    if let best = await self.performFallbackMatch(title: titleValue, artist: artistValue, duration: durationSeconds, candidates: items) {
                        return try? await self.resolveExternalStream(for: best.item)
                    }
                }
                return nil
            }

            // 2. YouTube Video Task
            group.addTask {
                try? Task.checkCancellation()
                let videoQuery = self.effectiveSearchQuery(for: query, scope: .video)
                let result = await self.fetchYouTubeSectionItems(query: videoQuery, updateUI: false)
                if case .success(let items) = result {
                    if let best = await self.performFallbackMatch(title: titleValue, artist: artistValue, duration: durationSeconds, candidates: items) {
                        return try? await self.resolveExternalStream(for: best.item)
                    }
                }
                return nil
            }

            for await payload in group {
                if Task.isCancelled { break }
                if let payload {
                    group.cancelAll()
                    return payload
                }
            }
            return nil
        }
    }

    nonisolated private func performFallbackMatch(
        title: String,
        artist: String,
        duration: TimeInterval?,
        candidates: [FederatedSearchItem]
    ) async -> SpotifyFallbackMatch? {
        return findBestSpotifyFallbackMatch(
            for: title,
            artist: artist,
            durationSeconds: duration,
            in: candidates
        )
    }

    private struct SpotifyFallbackMatch {
        let item: FederatedSearchItem
        let score: Double
    }

    nonisolated private func findBestSpotifyFallbackMatch(
        for title: String,
        artist: String,
        durationSeconds: TimeInterval?,
        in items: [FederatedSearchItem]
    ) -> SpotifyFallbackMatch? {
        let rankedMatches = items.compactMap { item -> SpotifyFallbackMatch? in
            let score = spotifyFallbackScore(
                sourceTitle: title,
                sourceArtist: artist,
                sourceDuration: durationSeconds,
                candidate: item
            )

            guard score >= 0.55 else { return nil }
            return SpotifyFallbackMatch(item: item, score: score)
        }

        return rankedMatches.max(by: { lhs, rhs in
            if lhs.score == rhs.score {
                return providerPriority(for: lhs.item.service) < providerPriority(for: rhs.item.service)
            }

            return lhs.score < rhs.score
        })
    }

    nonisolated private func spotifyFallbackScore(
        sourceTitle: String,
        sourceArtist: String,
        sourceDuration: TimeInterval?,
        candidate: FederatedSearchItem
    ) -> Double {
        let normalizedSourceTitle = normalizedRankingText(sourceTitle)
        let normalizedSourceArtist = normalizedRankingText(sourceArtist)
        let normalizedCandidateTitle = normalizedRankingText(candidate.title)
        let normalizedCandidateArtist = normalizedRankingText(primaryArtistName(from: candidate.subtitle))

        let titleOverlap = tokenOverlapScore(normalizedSourceTitle, normalizedCandidateTitle)
        let artistOverlap = tokenOverlapScore(normalizedSourceArtist, normalizedCandidateArtist)
        let titleContainsBonus = normalizedCandidateTitle.contains(normalizedSourceTitle) ? 0.16 : 0
        let sourceContainsBonus = normalizedSourceTitle.contains(normalizedCandidateTitle) ? 0.08 : 0
        let exactTitleBonus = normalizedSourceTitle == normalizedCandidateTitle ? 0.36 : 0
        let exactArtistBonus = normalizedSourceArtist == normalizedCandidateArtist ? 0.18 : 0
        let durationBonus = spotifyDurationMatchScore(
            sourceDuration: sourceDuration,
            candidateDuration: candidate.durationSeconds
        ) * 0.34
        let variantPenalty = spotifyVariantPenalty(
            sourceTitle: normalizedSourceTitle,
            candidateTitle: normalizedCandidateTitle
        )

        let providerBonus: Double
        switch candidate.service {
        case .youtubeMusic:
            providerBonus = 0.05
        case .youtube:
            providerBonus = 0.03
        case .spotify:
            providerBonus = 0
        }

        return (0.42 * titleOverlap)
            + (0.26 * artistOverlap)
            + titleContainsBonus
            + sourceContainsBonus
            + exactTitleBonus
            + exactArtistBonus
            + durationBonus
            + providerBonus
            + variantPenalty
    }

    nonisolated private func spotifyDurationMatchScore(sourceDuration: TimeInterval?, candidateDuration: TimeInterval?) -> Double {
        guard let sourceDuration, sourceDuration > 0 else { return 0.12 }
        guard let candidateDuration, candidateDuration > 0 else { return 0.12 }

        let delta = abs(sourceDuration - candidateDuration)
        let baseline = max(sourceDuration, candidateDuration, 1)
        let normalizedDelta = min(delta / baseline, 1)

        return max(0, 1 - (normalizedDelta * 3.5))
    }

    nonisolated private func spotifyVariantPenalty(sourceTitle: String, candidateTitle: String) -> Double {
        let sourceHasVariant = spotifyTitleHasVariantMarker(sourceTitle)
        let candidateHasVariant = spotifyTitleHasVariantMarker(candidateTitle)

        if candidateHasVariant && !sourceHasVariant {
            return -0.34
        }

        if sourceHasVariant && !candidateHasVariant {
            return -0.08
        }

        return 0
    }

    nonisolated private func spotifyTitleHasVariantMarker(_ title: String) -> Bool {
        let markers = [
            " remix",
            " live",
            " acoustic",
            " cover",
            " instrumental",
            " karaoke",
            " tribute",
            " mashup",
            " medley",
            " rework",
            " edit",
            " slowed",
            " sped up",
            " nightcore",
            " 8d",
            " mono",
            " remaster",
            " version"
        ]

        return markers.contains { title.contains($0) }
    }

    private func resetFederatedSections(state: FederatedSectionState) {
        federatedSections = FederatedSearchSection.defaultSections.map { section in
            var copy = section
            copy.state = state
            copy.items = []
            return copy
        }
    }

    private func applyFederatedSearchResult(
        _ result: Result<[FederatedSearchItem], Error>,
        for service: FederatedService
    ) {
        guard let index = federatedSections.firstIndex(where: { $0.service == service }) else { return }

        switch result {
        case .success(let items):
            federatedSections[index].items = Array(items.prefix(5))
            federatedSections[index].state = .success
        case .failure(let error):
            federatedSections[index].items = []
            federatedSections[index].state = .error(error.localizedDescription)
        }
    }

    private func setSectionState(_ state: FederatedSectionState, for service: FederatedService) {
        guard let index = federatedSections.firstIndex(where: { $0.service == service }) else { return }
        federatedSections[index].state = state
        federatedSections[index].items = []
    }

    public func firstSectionErrorMessage() -> String? {
        for service in UnifiedTopResultsPolicy.services {
            guard let section = federatedSections.first(where: { $0.service == service }) else {
                continue
            }

            if case .error(let message) = section.state {
                return message
            }
        }
        return nil
    }

    private struct UnifiedRankingContext {
        let normalizedQuery: String
        let youtubeArtistSignals: [String: Double]
        let dominantArtist: String?
        let queryHasArtistHint: Bool
    }

    nonisolated private func buildUnifiedTopResults(for query: String, in sections: [FederatedSearchSection]) -> [FederatedSearchItem] {
        let candidates = UnifiedTopResultsPolicy.services.flatMap { service in
            sections.first(where: { $0.service == service })?.items ?? []
        }
        guard !candidates.isEmpty else { return [] }

        let context = makeUnifiedRankingContext(for: query, candidates: candidates)
        var groupedCandidates: [String: [(item: FederatedSearchItem, score: Double)]] = [:]

        for item in candidates {
            let key = unifiedResultDedupKey(for: item)
            let score = unifiedResultScore(for: item, context: context)
            groupedCandidates[key, default: []].append((item: item, score: score))
        }

        let rankedGroups: [(item: FederatedSearchItem, score: Double)] = groupedCandidates.values.compactMap { group in
            guard let representative = group.max(by: { $0.score < $1.score }) else {
                return nil
            }

            let distinctServiceCount = Set(group.map { $0.item.service }).count
            let consensusBoost = consensusConfidenceBoost(forDistinctServiceCount: distinctServiceCount)
            return (item: representative.item, score: representative.score + consensusBoost)
        }
        .sorted { lhs, rhs in
            if lhs.score == rhs.score {
                return providerPriority(for: lhs.item.service) < providerPriority(for: rhs.item.service)
            }
            return lhs.score > rhs.score
        }

        return enforceServiceDiversity(
            on: rankedGroups.map { $0.item },
            limit: UnifiedTopResultsPolicy.limit,
            queryHasArtistHint: context.queryHasArtistHint
        )
    }

    nonisolated private func buildYouMightLikeResults(
        for query: String,
        in sections: [FederatedSearchSection],
        anchorResults: [FederatedSearchItem],
        excludingIDs: Set<String>
    ) -> [FederatedSearchItem] {
        let candidates = YouMightLikePolicy.services
            .flatMap { service in
                sections.first(where: { $0.service == service })?.items ?? []
            }
            .filter { !excludingIDs.contains($0.id) }
        guard !candidates.isEmpty else { return [] }

        let normalizedQuery = normalizedRankingText(query)
        let anchorTitle = normalizedRankingText(anchorResults.first?.title ?? "")
        let anchorArtist = normalizedRankingText(primaryArtistName(from: anchorResults.first?.subtitle ?? ""))

        let ranked = candidates.enumerated().map { index, item in
            let itemTitle = normalizedRankingText(item.title)
            let itemArtist = normalizedRankingText(primaryArtistName(from: item.subtitle))

            let querySimilarity = tokenOverlapScore(itemTitle, normalizedQuery)
            let anchorSimilarity = max(
                tokenOverlapScore(itemTitle, anchorTitle),
                tokenOverlapScore(itemArtist, anchorArtist)
            )
            let serviceBoost = item.service == .youtube ? 0.08 : 0.05
            let positionBoost = max(0.0, 0.12 - (Double(index) * 0.02))
            let score = (0.58 * querySimilarity) + (0.30 * anchorSimilarity) + serviceBoost + positionBoost

            return (item: item, score: score)
        }
        .sorted { lhs, rhs in
            if lhs.score == rhs.score {
                return providerPriority(for: lhs.item.service) < providerPriority(for: rhs.item.service)
            }
            return lhs.score > rhs.score
        }
        .map { $0.item }

        let deduplicated = dedupeByMetadataPreservingOrder(ranked)
        return Array(deduplicated.prefix(YouMightLikePolicy.limit))
    }

    nonisolated private func dedupeByMetadataPreservingOrder(_ items: [FederatedSearchItem]) -> [FederatedSearchItem] {
        var seen = Set<String>()
        var deduped: [FederatedSearchItem] = []

        for item in items {
            let key = unifiedResultDedupKey(for: item)
            if seen.insert(key).inserted {
                deduped.append(item)
            }
        }

        return deduped
    }

    nonisolated private func makeUnifiedRankingContext(for query: String, candidates: [FederatedSearchItem]) -> UnifiedRankingContext {
        let normalizedQuery = normalizedRankingText(query)
        let youtubeArtistSignals = buildYouTubeArtistSignals(from: candidates)
        let dominantArtist = youtubeArtistSignals
            .max(by: { lhs, rhs in lhs.value < rhs.value })?
            .key
        let queryHasArtistHint = queryContainsArtistHint(
            normalizedQuery,
            candidateArtists: Array(youtubeArtistSignals.keys)
        )

        return UnifiedRankingContext(
            normalizedQuery: normalizedQuery,
            youtubeArtistSignals: youtubeArtistSignals,
            dominantArtist: dominantArtist,
            queryHasArtistHint: queryHasArtistHint
        )
    }

    nonisolated private func buildYouTubeArtistSignals(from candidates: [FederatedSearchItem]) -> [String: Double] {
        var signals: [String: Double] = [:]

        let youtubeItems = candidates.filter { $0.service == .youtube }
        for (index, item) in youtubeItems.enumerated() {
            guard case .youtubeVideo(let video) = item.payload else { continue }

            let artist = normalizedRankingText(normalizedMusicDisplayArtist(video.author, title: video.title))
            guard !artist.isEmpty else { continue }

            let viewCount = parseYouTubeViewCount(video.viewCount)
            let positionWeight = max(0.30, 1.0 - (Double(index) * 0.16))
            let viewWeight = log10(max(10.0, viewCount + 10.0))
            let totalWeight = positionWeight + (viewWeight * 0.22)

            signals[artist, default: 0] += totalWeight
        }

        let youtubeMusicItems = candidates.filter { $0.service == .youtubeMusic }
        for (index, item) in youtubeMusicItems.enumerated() {
            let artist = normalizedRankingText(primaryArtistName(from: item.subtitle))
            guard !artist.isEmpty else { continue }
            let weight = max(0.20, 0.55 - (Double(index) * 0.10))
            signals[artist, default: 0] += weight
        }

        return signals
    }

    nonisolated private func queryContainsArtistHint(_ normalizedQuery: String, candidateArtists: [String]) -> Bool {
        if normalizedQuery.contains(" by ") {
            return true
        }

        let queryTokens = tokenSet(from: normalizedQuery)
        guard queryTokens.count >= 3 else { return false }

        for artist in candidateArtists {
            let artistTokenSet = Set(tokenSet(from: artist).filter { $0.count > 2 })
            guard !artistTokenSet.isEmpty else { continue }

            let overlap = Double(queryTokens.intersection(artistTokenSet).count) / Double(artistTokenSet.count)
            if overlap >= 0.67 {
                return true
            }
        }

        return false
    }

    nonisolated private func unifiedResultScore(for item: FederatedSearchItem, context: UnifiedRankingContext) -> Double {
        let searchableText = normalizedRankingText("\(item.title) \(primaryArtistName(from: item.subtitle))")
        let queryTokens = tokenSet(from: context.normalizedQuery)
        let itemTokens = tokenSet(from: searchableText)

        let overlap: Double
        if queryTokens.isEmpty {
            overlap = 0
        } else {
            overlap = Double(queryTokens.intersection(itemTokens).count) / Double(queryTokens.count)
        }

        let containsBoost = (!context.normalizedQuery.isEmpty && searchableText.contains(context.normalizedQuery)) ? 0.16 : 0
        let prefixBoost = (!context.normalizedQuery.isEmpty && searchableText.hasPrefix(context.normalizedQuery)) ? 0.06 : 0
        let providerBoost = providerConfidenceBoost(for: item.service, queryHasArtistHint: context.queryHasArtistHint)
        let qualityBoost = qualityConfidenceBoost(for: item)
        let playabilityBoost = item.isPlayable ? 0.03 : -0.12

        let artistAlignment = itemArtistAlignmentScore(for: item, dominantArtist: context.dominantArtist)
        let artistBoost = inferredArtistBoost(
            for: item.service,
            alignment: artistAlignment,
            hasDominantArtist: context.dominantArtist != nil,
            queryHasArtistHint: context.queryHasArtistHint
        )

        return (0.68 * overlap)
            + containsBoost
            + prefixBoost
            + providerBoost
            + qualityBoost
            + playabilityBoost
            + artistBoost
    }

    nonisolated private func itemArtistAlignmentScore(for item: FederatedSearchItem, dominantArtist: String?) -> Double {
        guard let dominantArtist, !dominantArtist.isEmpty else { return 0 }
        let itemArtist = normalizedRankingText(primaryArtistName(from: item.subtitle))
        guard !itemArtist.isEmpty else { return 0 }
        return tokenOverlapScore(itemArtist, dominantArtist)
    }

    nonisolated private func inferredArtistBoost(
        for service: FederatedService,
        alignment: Double,
        hasDominantArtist: Bool,
        queryHasArtistHint: Bool
    ) -> Double {
        guard hasDominantArtist else { return 0 }

        switch service {
        case .youtubeMusic:
            if alignment >= 0.75 { return 0.08 }
            if alignment >= 0.45 { return 0.04 }
            return 0
        case .youtube:
            if alignment >= 0.75 { return 0.06 }
            if alignment >= 0.45 { return 0.03 }
            return 0
        case .spotify:
            return 0
        }
    }

    nonisolated private func consensusConfidenceBoost(forDistinctServiceCount count: Int) -> Double {
        switch count {
        case 3...:
            return 0.10
        case 2:
            return 0.06
        default:
            return 0
        }
    }

    nonisolated private func enforceServiceDiversity(
        on rankedItems: [FederatedSearchItem],
        limit: Int,
        queryHasArtistHint: Bool
    ) -> [FederatedSearchItem] {
        guard limit > 0 else { return [] }

        var selected: [FederatedSearchItem] = []
        var selectedIDs = Set<String>()
        var serviceCounts: [FederatedService: Int] = [:]

        for item in rankedItems {
            let cap = UnifiedTopResultsPolicy.maxPerService[item.service] ?? limit

            if serviceCounts[item.service, default: 0] >= cap {
                continue
            }

            if selectedIDs.insert(item.id).inserted {
                selected.append(item)
                serviceCounts[item.service, default: 0] += 1
            }

            if selected.count == limit {
                return selected
            }
        }

        if selected.count < limit {
            for item in rankedItems {
                guard selectedIDs.insert(item.id).inserted else { continue }
                selected.append(item)
                if selected.count == limit {
                    break
                }
            }
        }

        return selected
    }

    nonisolated private func unifiedResultDedupKey(for item: FederatedSearchItem) -> String {
        let title = normalizedRankingText(item.title)
        let artist = normalizedRankingText(primaryArtistName(from: item.subtitle))
        return "\(title)|\(artist)"
    }

    nonisolated private func primaryArtistName(from subtitle: String) -> String {
        if let first = subtitle.split(separator: "•").first {
            let artist = String(first).trimmingCharacters(in: .whitespacesAndNewlines)
            if !artist.isEmpty {
                return artist
            }
        }

        return subtitle
    }

    nonisolated private func parseYouTubeViewCount(_ value: String) -> Double {
        let lowercased = value
            .lowercased()
            .replacingOccurrences(of: ",", with: "")

        if let compactRange = lowercased.range(of: "([0-9]+(?:\\.[0-9]+)?)\\s*([kmb])", options: .regularExpression) {
            let compact = String(lowercased[compactRange])
            let numericPart = compact.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
            guard let number = Double(numericPart) else { return 0 }

            if compact.contains("b") { return number * 1_000_000_000 }
            if compact.contains("m") { return number * 1_000_000 }
            if compact.contains("k") { return number * 1_000 }
            return number
        }

        if let numberRange = lowercased.range(of: "[0-9]+(?:\\.[0-9]+)?", options: .regularExpression),
           let number = Double(lowercased[numberRange]) {
            if lowercased.contains("billion") { return number * 1_000_000_000 }
            if lowercased.contains("million") { return number * 1_000_000 }
            if lowercased.contains("thousand") { return number * 1_000 }
            return number
        }

        return 0
    }

    nonisolated private func providerPriority(for service: FederatedService) -> Int {
        switch service {
        case .youtubeMusic:
            return 1
        case .youtube:
            return 2
        case .spotify:
            return 3
        }
    }

    nonisolated private func providerConfidenceBoost(for service: FederatedService, queryHasArtistHint: Bool) -> Double {
        switch service {
        case .youtube:
            return queryHasArtistHint ? 0.03 : 0.04
        case .youtubeMusic:
            return queryHasArtistHint ? 0.02 : 0.03
        case .spotify:
            return 0
        }
    }

    private func upsertCanonicalYouTubeMusicSongs(_ songs: [YouTubeMusicSong]) {
        guard let centralMediaStore else { return }

        for song in songs {
            let artistName = primaryArtistName(from: song.artistsDisplay)
            _ = centralMediaStore.upsertSong(
                .init(
                    title: song.title,
                    normalizedTitle: normalizedRankingText(song.title),
                    primaryArtistName: artistName.isEmpty ? nil : artistName,
                    primaryArtistID: nil,
                    albumTitle: song.album,
                    albumID: nil,
                    durationSeconds: song.duration,
                    artworkURLString: song.thumbnailURL?.absoluteString,
                    isExplicit: song.isExplicit,
                    providerFingerprint: songFingerprint(title: song.title, artist: artistName),
                    spotifyTrackID: nil,
                    spotifyTrackURI: nil,
                    spotifyPreviewURLString: nil,
                    youtubeVideoID: nil,
                    youtubeMusicVideoID: song.videoId,
                    appleMusicSongID: nil
                )
            )
        }
    }

    private func upsertCanonicalYouTubeVideos(_ videos: [YouTubeVideo]) {
        guard let centralMediaStore else { return }

        for video in videos {
            let artistName = video.author
            _ = centralMediaStore.upsertSong(
                .init(
                    title: video.title,
                    normalizedTitle: normalizedRankingText(video.title),
                    primaryArtistName: artistName.isEmpty ? nil : artistName,
                    primaryArtistID: nil,
                    albumTitle: nil,
                    albumID: nil,
                    durationSeconds: parseVideoDurationSeconds(video.lengthInSeconds),
                    artworkURLString: video.thumbnailURL,
                    isExplicit: false,
                    providerFingerprint: songFingerprint(title: video.title, artist: artistName),
                    spotifyTrackID: nil,
                    spotifyTrackURI: nil,
                    spotifyPreviewURLString: nil,
                    youtubeVideoID: video.id,
                    youtubeMusicVideoID: nil,
                    appleMusicSongID: nil
                )
            )
        }
    }


    private func songFingerprint(title: String, artist: String) -> String {
        let normalizedTitle = normalizedRankingText(title)
        let normalizedArtist = normalizedRankingText(artist)
        return normalizedArtist.isEmpty ? normalizedTitle : "\(normalizedTitle)|\(normalizedArtist)"
    }

    nonisolated private func qualityConfidenceBoost(for item: FederatedSearchItem) -> Double {
        let quality = normalizedRankingText(item.audioQualityLabel ?? "")
        let codec = normalizedRankingText(item.audioCodecLabel ?? "")

        var boost: Double = 0

        if quality.contains("hi res") {
            boost += 0.06
        } else if quality.contains("lossless") {
            boost += 0.05
        } else if quality.contains("high") {
            boost += 0.02
        }

        if codec == "flac" {
            boost += 0.02
        } else if codec == "aac" {
            boost += 0.005
        }

        return boost
    }

    nonisolated private func fetchYouTubeMusicSectionItems(query: String, updateUI: Bool) async -> Result<[FederatedSearchItem], Error> {
        do {
            let results = try await youtube.music.search(query)
            if updateUI {
                await MainActor.run {
                    self.musicResults = results
                    self.searchCache.setMusicResults(results, for: query)
                    self.searchCacheHintStore.recordMusicResults(query: query, results: results)
                }

                let topResultsForPrefetch = Array(results.prefix(2))
                let prefetchIDs = topResultsForPrefetch.map(\.videoId)
                await MainActor.run {
                    self.prefetchTopResultIDs(prefetchIDs)
                }

                let topResultsForUI = Array(results.prefix(5))
                await MainActor.run {
                    self.upsertCanonicalYouTubeMusicSongs(topResultsForUI)
                }
            }

            let items = results.prefix(5).map { song in
                FederatedSearchItem(
                    id: "ytm-\(song.videoId)",
                    title: normalizedMusicDisplayTitle(song.title, artist: song.artistsDisplay),
                    subtitle: "\(normalizedMusicDisplayArtist(song.artistsDisplay, title: song.title)) • \(song.album ?? "Single")",
                    artworkURL: song.thumbnailURL,
                    durationSeconds: song.duration,
                    isPlayable: true,
                    isExplicit: song.isExplicit,
                    audioQualityLabel: nil,
                    audioCodecLabel: nil,
                    payload: .youtubeMusic(song)
                )
            }

            return .success(items)
        } catch {
            return .failure(error)
        }
    }

    nonisolated private func fetchYouTubeSectionItems(query: String, updateUI: Bool) async -> Result<[FederatedSearchItem], Error> {
        do {
            let continuation = try await youtube.main.search(query)
            
            let topVideos: [YouTubeVideo]
            if updateUI {
                let videoResults = await MainActor.run {
                    self.resetVideoPagination()
                    self.updateVideoResults(with: continuation, appending: false)
                    let results = self.videoResults
                    self.searchCache.setVideoResults(results, for: query)
                    self.searchCacheHintStore.recordVideoResults(query: query, results: results)
                    return results
                }
                
                topVideos = Array(videoResults.compactMap { item -> YouTubeVideo? in
                    if case .video(let video) = item { return video }
                    return nil
                }.prefix(5))
            } else {
                topVideos = Array(continuation.items.compactMap { item -> YouTubeVideo? in
                    if case .video(let video) = item { return video }
                    return nil
                }.prefix(5))
            }

            let items = topVideos.map { video in
                FederatedSearchItem(
                    id: "yt-\(video.id)",
                    title: normalizedMusicDisplayTitle(video.title, artist: video.author),
                    subtitle: normalizedMusicDisplayArtist(video.author, title: video.title),
                    artworkURL: normalizedArtworkURL(from: video.thumbnailURL),
                    durationSeconds: self.parseVideoDurationSeconds(video.lengthInSeconds),
                    isPlayable: true,
                    isExplicit: false,
                    audioQualityLabel: nil,
                    audioCodecLabel: nil,
                    payload: .youtubeVideo(video)
                )
            }

            return .success(Array(items))
        } catch {
            return .failure(error)
        }
    }

    // Result type carrying all three Spotify visible sections
    public struct SpotifySearchItems {
        let tracks: [FederatedSearchItem]
        let artists: [FederatedSearchItem]
        let playlists: [FederatedSearchItem]
    }

    nonisolated private func fetchSpotifySectionItems(query: String) async -> Result<SpotifySearchItems, Error> {
#if canImport(SpotifySDK)
        do {
            let spotify = try await makeSpotifyClient()
            let results = try await spotify.search.search(
                query,
                limit: 8,
                numberOfTopResults: 5,
                includeAudiobooks: false
            )

            let sourceTracks = Array((results.tracks?.items ?? []).prefix(8))
            let sourceArtists = Array((results.artists?.items ?? []).prefix(4))
            let sourcePlaylists = Array((results.playlists?.items ?? []).prefix(4))

            await MainActor.run {
                if let centralMediaStore = self.centralMediaStore {
                    _ = centralMediaStore.upsertSpotifyTracks(sourceTracks)
                    _ = centralMediaStore.upsertSpotifyArtists(sourceArtists)
                    _ = centralMediaStore.upsertSpotifyPlaylists(sourcePlaylists)
                }
            }

            // Tracks
            let trackItems: [FederatedSearchItem] = sourceTracks.map { track in
                let spotifyTrack = SpotifySearchTrack(
                    id: track.id,
                    title: track.name,
                    artistName: track.artists.first?.name ?? "Unknown Artist",
                    albumName: track.album?.name,
                    artworkURL: track.album?.images.first?.url,
                    durationSeconds: TimeInterval(track.durationMS) / 1000,
                    previewURL: track.previewURL
                )
                return FederatedSearchItem(
                    id: "spotify-\(track.id)",
                    title: spotifyTrack.title,
                    subtitle: "\(spotifyTrack.artistName) • \(spotifyTrack.albumName ?? "Spotify")",
                    artworkURL: spotifyTrack.artworkURL,
                    durationSeconds: spotifyTrack.durationSeconds,
                    isPlayable: true, // resolved via hidden providers
                    isExplicit: track.isExplicit ?? false,
                    audioQualityLabel: nil,
                    audioCodecLabel: nil,
                    payload: .spotify(spotifyTrack)
                )
            }

            // Artists
            let artistItems: [FederatedSearchItem] = sourceArtists.map { artist in
                let artworkURL = artist.images.first?.url
                return FederatedSearchItem(
                    id: "spotify-artist-\(artist.id)",
                    title: artist.name,
                    subtitle: "Artist",
                    artworkURL: artworkURL,
                    durationSeconds: nil,
                    isPlayable: false,
                    isExplicit: false,
                    audioQualityLabel: nil,
                    audioCodecLabel: nil,
                    payload: .spotifyArtist(SpotifySearchArtist(
                        id: artist.id,
                        name: artist.name,
                        artworkURL: artworkURL,
                        genres: artist.genres
                    ))
                )
            }

            // Playlists
            let playlistItems: [FederatedSearchItem] = sourcePlaylists.map { playlist in
                let artworkURL = playlist.images.first?.url
                let ownerName = playlist.owner?.displayName ?? "Spotify"
                return FederatedSearchItem(
                    id: "spotify-playlist-\(playlist.id)",
                    title: playlist.name,
                    subtitle: "Playlist • \(ownerName)",
                    artworkURL: artworkURL,
                    durationSeconds: nil,
                    isPlayable: false,
                    isExplicit: false,
                    audioQualityLabel: nil,
                    audioCodecLabel: nil,
                    payload: .spotifyPlaylist(SpotifySearchPlaylist(
                        id: playlist.id,
                        uri: playlist.uri,
                        name: playlist.name,
                        ownerName: ownerName,
                        artworkURL: artworkURL,
                        totalTracks: playlist.totalTracks
                    ))
                )
            }

            return .success(SpotifySearchItems(
                tracks: trackItems,
                artists: artistItems,
                playlists: playlistItems
            ))
        } catch {
            return .failure(error)
        }
#else
        return .failure(FederatedSearchError.providerUnavailable("SpotifySDK is not linked to this target."))
#endif
    }

    nonisolated private func parseVideoDurationSeconds(_ value: String?) -> TimeInterval? {
        guard let value else { return nil }
        return Double(value)
    }

    private func inferCodecLabel(from url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        if ext == "flac" { return "FLAC" }
        if ext == "m3u8" { return "HLS" }
        if ext == "aac" || ext == "m4a" || ext == "mp4" { return "AAC" }
        if ext == "mp3" { return "MP3" }
        return "Unknown"
    }

    private func inferCodecLabelIfKnown(from url: URL?) -> String? {
        guard let url else { return nil }
        let label = inferCodecLabel(from: url)
        return label == "Unknown" ? nil : label
    }

#if canImport(SpotifySDK)
    private func makeSpotifyClient() async throws -> SpotifySDK {
        let coordinator = SpotifySessionCoordinator.shared
        if !coordinator.didAttemptRestore {
            await coordinator.restoreSessionIfNeeded()
        }

        if let sdk = coordinator.sdk {
            return sdk
        }

        if streamingProviderSettings.spotifyPreferAnonymousFallback {
            // This is a stateless fallback client for public search
            return SpotifySDK(mode: .anonymous)
        }

        throw FederatedSearchError.spotifyCredentialsMissing
    }

    /// Fetches Spotify search suggestions; returns [] silently on any failure.
    private func fetchSpotifySuggestions(query: String) async -> [String] {
        guard let spotify = try? await makeSpotifyClient() else { return [] }
        let suggestions = try? await spotify.search.searchSuggestions(query, limit: 10, numberOfTopResults: 10)
        return suggestions?.map(\.title) ?? []
    }
#endif


    public func applySuggestion(_ suggestion: String) {
        let cleaned = suggestion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        searchTask?.cancel()
        searchText = cleaned
        historyStore.recordSearch(query: cleaned)
        Task { await executeSearch() }
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
            // Also prewarm quick-playback URLs (HLS preferred) so the player can start immediately.
            let resolver = await PlaybackURLResolver.sharedInstance()
            await resolver.prewarm(ids)
        }
    }

    // Public helper to prefetch a single id (used by row onAppear)
    public func prefetchIfNeeded(id: String) {
    }

    private func scheduleInlinePrefetchDrainIfNeeded() {
        guard inlinePrefetchDrainTask == nil else { return }

        let youtube = self.youtube
        let mode = effectivePrefetchMode
        let metricsEnabled = settings.metricsEnabled
        let concurrency = max(1, min(2, currentPrefetchConcurrency))

        inlinePrefetchDrainTask = Task(priority: .utility) {
            try? await Task.sleep(for: inlinePrefetchCoalesceWindow)
            if Task.isCancelled {
                inlinePrefetchDrainTask = nil
                return
            }

            let ids = Array(inlinePrefetchPendingIDs)
            inlinePrefetchPendingIDs.removeAll(keepingCapacity: true)
            guard !ids.isEmpty else {
                inlinePrefetchDrainTask = nil
                return
            }

            await self.metadataCache.prefetch(
                ids: ids,
                maxConcurrent: concurrency,
                mode: mode,
                metricsEnabled: metricsEnabled
            ) { key in
                try await youtube.main.video(id: key)
            }

            // Warm quick-playback URLs for these inline-prefetch IDs as well.
            let resolver = await PlaybackURLResolver.sharedInstance()
            await resolver.prewarm(ids)

            inlinePrefetchDrainTask = nil
            if !inlinePrefetchPendingIDs.isEmpty {
                scheduleInlinePrefetchDrainIfNeeded()
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
            // Fetch from Spotify, YouTube, and YouTube Music in parallel
            #if canImport(SpotifySDK)
            async let spotifySuggestionsTask: [String] = fetchSpotifySuggestions(query: query)
            #else
            async let spotifySuggestionsTask: [String] = []
            #endif
            async let youtubeSuggestionsTask = youtube.main.getSearchSuggestions(query: query)
            async let musicSuggestionsTask = youtube.music.getSearchSuggestions(query: query)

            let spotifySuggestions = await spotifySuggestionsTask
            let youtubeSuggestions = (try? await youtubeSuggestionsTask) ?? []
            let musicSuggestions = (try? await musicSuggestionsTask) ?? []

            // Merge: Spotify first (richest), then YouTube deduped
            var seenSuggestionKeys = Set<String>()
            let merged = (spotifySuggestions + youtubeSuggestions + musicSuggestions).filter { suggestion in
                let key = suggestion.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                guard !key.isEmpty else { return false }
                return seenSuggestionKeys.insert(key).inserted
            }
            let remote = merged

            let local = historyStore.topCandidates(prefix: query, limit: 20)
            var candidates: [SuggestionCandidate] = []

            candidates.append(contentsOf: remote.map {
                SuggestionCandidate(
                    text: $0,
                    frequency: 0,
                    successfulPlays: 0,
                    recency: Date.distantPast,
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
            suggestions = historyStore.topCandidates(prefix: query, limit: 8).map { $0.query }
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
                    searchCacheHintStore.recordMusicResults(query: normalizedTop, results: results)
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
                    searchCacheHintStore.recordVideoResults(query: normalizedTop, results: mapped)
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

    public func loadMoreVideosIfNeeded(for item: YouTubeSearchResult) {
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
            case .channel(let c):
                guard shouldKeepMusicChannel(c) else { return nil }
                return .channel(c)
            case .playlist(let p):
                guard shouldKeepMusicPlaylist(p) else { return nil }
                return .playlist(p)
            default: return nil
            }
        }
    }

    nonisolated private func effectiveSearchQuery(for query: String, scope: SearchScope) -> String {
        switch scope {
        case .music:
            return query
        case .video:
            return musicVideoSearchQuery(query)
        }
    }

    private func shouldKeepVideoResult(_ video: YouTubeVideo) -> Bool {
        shouldKeepMusicVideoResult(video)
    }

    private func resetVideoPagination() {
        videoContinuationToken = nil
        isLoadingMoreVideos = false
        videoContinuationBadResponseCount = 0
        lastPaginationTriggerAt = nil
        lastPaginationTriggerToken = nil
    }
    
    public func recordSuccessfulPlayFromCurrentQuery() {
        // Track successful play to improve future search rankings
    }
}
