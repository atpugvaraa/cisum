import Foundation
import Observation
import SwiftData
import YouTubeSDK

@Observable
@MainActor
public final class CoreServices {
    public let prefetchSettings: PrefetchSettings
    public let networkMonitor: NetworkPathMonitor

    public init(
        prefetchSettings: PrefetchSettings,
        networkMonitor: NetworkPathMonitor
    ) {
        self.prefetchSettings = prefetchSettings
        self.networkMonitor = networkMonitor
    }
}

@Observable
@MainActor
public final class PlaybackServices {
    public let playbackControlSettings: PlaybackControlSettings
    public let playbackMetricsStore: PlaybackMetricsStore
    public let lastFMSettings: LastFMSettings
    public let lastFMScrobbler: LastFMScrobbler
    public let listeningHistoryStore: ListeningHistoryStore
    public let streamingProviderSettings: StreamingProviderSettings
    public let radioSessionStore: RadioSessionStore
    public let artworkVideoProcessor: ArtworkVideoProcessor
    public let playerViewModel: any PlayerViewModelInterface

    public init(
        playbackControlSettings: PlaybackControlSettings,
        playbackMetricsStore: PlaybackMetricsStore,
        lastFMSettings: LastFMSettings,
        lastFMScrobbler: LastFMScrobbler,
        listeningHistoryStore: ListeningHistoryStore,
        streamingProviderSettings: StreamingProviderSettings,
        radioSessionStore: RadioSessionStore,
        artworkVideoProcessor: ArtworkVideoProcessor,
        playerViewModel: any PlayerViewModelInterface
    ) {
        self.playbackControlSettings = playbackControlSettings
        self.playbackMetricsStore = playbackMetricsStore
        self.lastFMSettings = lastFMSettings
        self.lastFMScrobbler = lastFMScrobbler
        self.listeningHistoryStore = listeningHistoryStore
        self.streamingProviderSettings = streamingProviderSettings
        self.radioSessionStore = radioSessionStore
        self.artworkVideoProcessor = artworkVideoProcessor
        self.playerViewModel = playerViewModel
    }
}

@Observable
@MainActor
public final class SearchServices {
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

@Observable
@MainActor
public final class LibraryServices {
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

@Observable
@MainActor
public final class UserServices {
    public let spotifySessionCoordinator: SpotifySessionCoordinator
    public let authService: AuthService
    public let supabaseService: SupabaseService
    public let analyticsService: AnalyticsService

    public init(
        spotifySessionCoordinator: SpotifySessionCoordinator,
        authService: AuthService,
        supabaseService: SupabaseService,
        analyticsService: AnalyticsService
    ) {
        self.spotifySessionCoordinator = spotifySessionCoordinator
        self.authService = authService
        self.supabaseService = supabaseService
        self.analyticsService = analyticsService
    }
}

@Observable
@MainActor
public final class ProviderServices {
    public let youtube: YouTube
    public let streamingProviderSettings: StreamingProviderSettings

    public init(
        youtube: YouTube,
        streamingProviderSettings: StreamingProviderSettings
    ) {
        self.youtube = youtube
        self.streamingProviderSettings = streamingProviderSettings
    }
}

@Observable
@MainActor
public final class AppServices {
    public let router: Router
    public let modelContainer: ModelContainer
    public let playerPresentationController: PlayerPresentationController
    public let searchOverlayController: SearchOverlayController

    public init(
        router: Router,
        modelContainer: ModelContainer,
        playerPresentationController: PlayerPresentationController,
        searchOverlayController: SearchOverlayController
    ) {
        self.router = router
        self.modelContainer = modelContainer
        self.playerPresentationController = playerPresentationController
        self.searchOverlayController = searchOverlayController
    }
}