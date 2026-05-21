import Observation
import Foundation

@Observable
@MainActor
public final class ServicesContainer {
    public let coreServices: CoreServices
    public let playbackServices: PlaybackServices
    public let searchServices: SearchServices
    public let libraryServices: LibraryServices
    public let userServices: UserServices
    public let providerServices: ProviderServices
    public let appServices: AppServices

    public init(
        coreServices: CoreServices,
        playbackServices: PlaybackServices,
        searchServices: SearchServices,
        libraryServices: LibraryServices,
        userServices: UserServices,
        providerServices: ProviderServices,
        appServices: AppServices
    ) {
        self.coreServices = coreServices
        self.playbackServices = playbackServices
        self.searchServices = searchServices
        self.libraryServices = libraryServices
        self.userServices = userServices
        self.providerServices = providerServices
        self.appServices = appServices
    }

    public var core: CoreInterface {
        CoreInterface(
            streamingProviderSettings: providerServices.streamingProviderSettings,
            prefetchSettings: coreServices.prefetchSettings,
            networkMonitor: coreServices.networkMonitor
        )
    }

    public var playback: PlaybackInterface {
        PlaybackInterface(
            playbackControlSettings: playbackServices.playbackControlSettings,
            playbackMetricsStore: playbackServices.playbackMetricsStore,
            streamingProviderSettings: playbackServices.streamingProviderSettings,
            radioSessionStore: playbackServices.radioSessionStore,
            artworkVideoProcessor: playbackServices.artworkVideoProcessor,
            playerViewModel: playbackServices.playerViewModel
        )
    }

    public var search: SearchInterface {
        SearchInterface(
            historyStore: searchServices.historyStore,
            searchCacheHintStore: searchServices.searchCacheHintStore,
            searchCache: searchServices.searchCache,
            suggestionRanker: searchServices.suggestionRanker,
            networkMonitor: searchServices.networkMonitor,
            prefetchSettings: searchServices.prefetchSettings,
            searchViewModel: searchServices.searchViewModel
        )
    }

    public var library: LibraryInterface {
        LibraryInterface(
            playlistLibraryStore: libraryServices.playlistLibraryStore,
            playlistImportJobStore: libraryServices.playlistImportJobStore,
            centralMediaStore: libraryServices.centralMediaStore,
            mediaCacheStore: libraryServices.mediaCacheStore,
            metadataCache: libraryServices.metadataCache
        )
    }

    public var user: UserInterface {
        UserInterface(
            spotifySessionCoordinator: userServices.spotifySessionCoordinator,
            authService: userServices.authService,
            supabaseService: userServices.supabaseService,
            analyticsService: userServices.analyticsService
        )
    }

    public var app: AppInterface {
        AppInterface(
            youtube: providerServices.youtube,
            router: appServices.router,
            modelContainer: appServices.modelContainer,
            playerPresentationController: appServices.playerPresentationController,
            searchOverlayController: appServices.searchOverlayController
        )
    }
}
