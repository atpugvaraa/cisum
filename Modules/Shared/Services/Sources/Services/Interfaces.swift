import Foundation
import YouTubeSDK
import SwiftData
import Observation

// MARK: - Interfaces

public struct PlaybackInterface {
    public let playbackControlSettings: PlaybackControlSettings
    public let playbackMetricsStore: PlaybackMetricsStore
    public let streamingProviderSettings: StreamingProviderSettings
    public let radioSessionStore: RadioSessionStore
    public let artworkVideoProcessor: ArtworkVideoProcessor
    public let playerViewModel: any PlayerViewModelInterface
    
    public init(
        playbackControlSettings: PlaybackControlSettings,
        playbackMetricsStore: PlaybackMetricsStore,
        streamingProviderSettings: StreamingProviderSettings,
        radioSessionStore: RadioSessionStore,
        artworkVideoProcessor: ArtworkVideoProcessor,
        playerViewModel: any PlayerViewModelInterface
    ) {
        self.playbackControlSettings = playbackControlSettings
        self.playbackMetricsStore = playbackMetricsStore
        self.streamingProviderSettings = streamingProviderSettings
        self.radioSessionStore = radioSessionStore
        self.artworkVideoProcessor = artworkVideoProcessor
        self.playerViewModel = playerViewModel
    }
}

public struct SearchInterface {
    public let historyStore: SearchHistoryStore
    public let searchCacheHintStore: SearchCacheHintStore
    public let searchCache: any SearchResultsCaching
    public let suggestionRanker: SuggestionRanker.Type
    public let networkMonitor: NetworkPathMonitor
    public let prefetchSettings: PrefetchSettings
    public let searchViewModel: any SearchViewModelInterface
    
    public init(
        historyStore: SearchHistoryStore,
        searchCacheHintStore: SearchCacheHintStore,
        searchCache: any SearchResultsCaching,
        suggestionRanker: SuggestionRanker.Type,
        networkMonitor: NetworkPathMonitor,
        prefetchSettings: PrefetchSettings,
        searchViewModel: any SearchViewModelInterface
    ) {
        self.historyStore = historyStore
        self.searchCacheHintStore = searchCacheHintStore
        self.searchCache = searchCache
        self.suggestionRanker = suggestionRanker
        self.networkMonitor = networkMonitor
        self.prefetchSettings = prefetchSettings
        self.searchViewModel = searchViewModel
    }
}

public struct LibraryInterface {
    public let playlistLibraryStore: PlaylistLibraryStore
    public let playlistImportJobStore: PlaylistImportJobStore
    public let centralMediaStore: CentralMediaStore
    public let mediaCacheStore: MediaCacheStore
    public let metadataCache: any VideoMetadataCaching
    
    public init(
        playlistLibraryStore: PlaylistLibraryStore,
        playlistImportJobStore: PlaylistImportJobStore,
        centralMediaStore: CentralMediaStore,
        mediaCacheStore: MediaCacheStore,
        metadataCache: any VideoMetadataCaching
    ) {
        self.playlistLibraryStore = playlistLibraryStore
        self.playlistImportJobStore = playlistImportJobStore
        self.centralMediaStore = centralMediaStore
        self.mediaCacheStore = mediaCacheStore
        self.metadataCache = metadataCache
    }
}

public struct UserInterface {
    public let spotifySessionCoordinator: SpotifySessionCoordinator
    
    public init(spotifySessionCoordinator: SpotifySessionCoordinator) {
        self.spotifySessionCoordinator = spotifySessionCoordinator
    }
}

public struct AppInterface {
    public let youtube: YouTube
    public let router: Router
    public let modelContainer: ModelContainer
    
    public init(youtube: YouTube, router: Router, modelContainer: ModelContainer) {
        self.youtube = youtube
        self.router = router
        self.modelContainer = modelContainer
    }
}

public struct CoreInterface {
    public let streamingProviderSettings: StreamingProviderSettings
    public let prefetchSettings: PrefetchSettings
    public let networkMonitor: NetworkPathMonitor
    
    public init(
        streamingProviderSettings: StreamingProviderSettings,
        prefetchSettings: PrefetchSettings,
        networkMonitor: NetworkPathMonitor
    ) {
        self.streamingProviderSettings = streamingProviderSettings
        self.prefetchSettings = prefetchSettings
        self.networkMonitor = networkMonitor
    }
}
