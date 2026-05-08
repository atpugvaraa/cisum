import SwiftUI
import DesignSystem
import Home
import Discover
import Library
import Player
import Search
import Services
import Profile
import SwiftData
import Models
import YouTubeSDK

@MainActor
public final class cisumModule {

    // MARK: - Feature Modules

    internal let home: HomeModule
    internal let discover: DiscoverModule
    internal let library: LibraryModule
    internal let player: PlayerModule
    internal let search: SearchModule
    internal let profile: ProfileModule

    // MARK: - Dependencies
    public let navigationState: NavigationState
    private let appRouter: AppRouter
    public let container: ServicesContainer
    private let coreDomain: CoreInterface
    private let playbackDomain: PlaybackInterface
    private let searchDomain: SearchInterface
    private let libraryDomain: LibraryInterface
    private let userDomain: UserInterface
    private let appDomain: AppInterface

    public var router: Router {
        appRouter
    }

    public var modelContainer: ModelContainer {
        appDomain.modelContainer
    }

    public func handleScenePhaseChange(_ phase: ScenePhase) {
        player.handleScenePhaseChange(phase)
        
        if phase != .active {
            coreDomain.prefetchSettings.flushPendingWrites()
            playbackDomain.playbackControlSettings.flushPendingWrites()
        }
    }

    // MARK: - Neutral Facades

    public var homeView: AnyView {
        AnyView(home.view)
    }

    public var discoverView: AnyView {
        AnyView(discover.view)
    }

    public var libraryView: AnyView {
        AnyView(library.view)
    }

    public var searchView: AnyView {
        AnyView(search.view)
    }

    public var settingsView: AnyView {
        AnyView(profile.settingsView)
    }

    public var searchText: Binding<String> {
        search.searchText
    }

    public func performSearch() {
        search.performSearch()
    }

    public var playerAccentColor: Color {
        player.accentColor
    }

    public var currentVideoId: String? {
        player.currentVideoId
    }

    public func miniPlayer(isExpanded: Binding<Bool>, namespace: Namespace.ID) -> AnyView {
        AnyView(player.miniPlayer(isExpanded: isExpanded, namespace: namespace))
    }

    public func expandablePlayer(show: Binding<Bool>, isExpanded: Binding<Bool>, collapsedFrame: CGRect) -> AnyView {
        AnyView(player.expandablePlayer(show: show, isExpanded: isExpanded, collapsedFrame: collapsedFrame))
    }

    #if os(iOS)
    public var systemVolumeController: SystemVolumeController {
        SystemVolumeController.shared
    }
    #endif

    // MARK: - Root View

    public var rootView: some View {
        DesignSystem.RootView(playerOverlayState: .init()) {
            RootView(module: self)
                .environment(self.container)
                .environment(self.container.coreServices)
                .environment(self.container.playbackServices)
                .environment(self.container.searchServices)
                .environment(self.container.libraryServices)
                .environment(self.container.userServices)
                .environment(self.container.providerServices)
                .environment(self.container.appServices)
        } overlayWrapper: { overlay in
            AnyView(
                overlay
                    .environment(self.container)
                    .environment(self.container.coreServices)
                    .environment(self.container.playbackServices)
                    .environment(self.container.searchServices)
                    .environment(self.container.libraryServices)
                    .environment(self.container.userServices)
                    .environment(self.container.providerServices)
                    .environment(self.container.appServices)
            )
        }
    }

    // MARK: - Init

    public init() {
        let navigationState = NavigationState()
        let appRouter = AppRouter()
        
        appRouter.onTabSwitch = { [weak navigationState] tab in
            navigationState?.selectedTab = tab
        }
        
        self.navigationState = navigationState
        self.appRouter = appRouter
        
        let youtube = YouTube()
        let container = AppBootstrap.makeDependenciesOrFallback(youtube: youtube, router: appRouter)
        self.container = container
        
        // 1. Store Interfaces
        self.coreDomain = container.core
        self.playbackDomain = container.playback
        self.searchDomain = container.search
        self.libraryDomain = container.library
        self.userDomain = container.user
        self.appDomain = container.app

        // 2. Initialize Features
        self.home = HomeModule()
        self.discover = DiscoverModule()
        self.library = LibraryModule()
        
        self.player = PlayerModule(
            dependencies: PlayerDependencies(viewModel: container.playback.playerViewModel)
        )
        
        self.profile = ProfileModule(
            prefetchSettings: container.core.prefetchSettings,
            networkMonitor: container.core.networkMonitor,
            playbackControlSettings: container.playback.playbackControlSettings,
            streamingProviderSettings: container.playback.streamingProviderSettings
        )
        
        self.search = SearchModule(
            dependencies: SearchDependencies(
                youtube: container.app.youtube,
                settings: container.core.prefetchSettings,
                networkMonitor: container.core.networkMonitor,
                historyStore: container.search.historyStore,
                searchCacheHintStore: container.search.searchCacheHintStore,
                streamingProviderSettings: container.playback.streamingProviderSettings,
                centralMediaStore: container.library.centralMediaStore,
                metadataCache: container.library.metadataCache,
                searchCache: container.search.searchCache,
                spotifySessionCoordinator: container.user.spotifySessionCoordinator,
                viewModel: container.search.searchViewModel
            )
        )
    }
}
