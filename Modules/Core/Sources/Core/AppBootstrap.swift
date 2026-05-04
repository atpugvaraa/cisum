//
//  AppBootstrap.swift
//  cisum
//
//  Created by Aarav Gupta on 28/03/26.
//

import Foundation
import SwiftData
import YouTubeSDK
import Services
import Search
import Player
import Models
import DesignSystem

@MainActor
enum AppBootstrap {
    static func makeDependenciesOrFallback(youtube: YouTube, router: Router) -> ServicesContainer {
        // FORCE IN-MEMORY FOR DIAGNOSTICS
        // return makeInMemoryDependencies(youtube: youtube, router: router, underlyingError: NSError(domain: "ManualBypass", code: 0))
        
        do {
            return try makeDependencies(youtube: youtube, router: router)
        } catch {
            print("❌ SwiftData bootstrap error:", error)
            // assertionFailure("Persistent bootstrap failed: \(error.localizedDescription). Falling back to in-memory dependencies.")
            return makeInMemoryDependencies(youtube: youtube, router: router, underlyingError: error)
        }
    }

    static func makeDependencies(youtube: YouTube, router: Router) throws -> ServicesContainer {
        let modelContainer = try makePersistentModelContainer()
        return buildDependencies(youtube: youtube, router: router, modelContainer: modelContainer)
    }

    private static func buildDependencies(
        youtube: YouTube,
        router: Router,
        modelContainer: ModelContainer
    ) -> ServicesContainer {
        let prefetchSettings = PrefetchSettings.shared
        let networkMonitor = NetworkPathMonitor.shared
        let playbackControlSettings = PlaybackControlSettings.shared
        let streamingProviderSettings = StreamingProviderSettings.shared
        let modelContext = ModelContext(modelContainer)
        let historyStore = Services.SearchHistoryStore(context: modelContext)
        let mediaCacheStore = MediaCacheStore(context: modelContext)
        let searchCacheHintStore = Services.SearchCacheHintStore(context: modelContext)
        let playlistLibraryStore = PlaylistLibraryStore(context: modelContext)
        let playlistImportJobStore = PlaylistImportJobStore(context: modelContext)
        let centralMediaStore = CentralMediaStore(context: modelContext)
        let artworkVideoProcessor = ArtworkVideoProcessor.shared
        let metadataCache = VideoMetadataCache.shared
        let searchCache = SearchResultsCache.shared
        let radioSessionStore = RadioSessionStore.shared
        let playbackMetricsStore = PlaybackMetricsStore.shared
        let spotifySessionCoordinator = SpotifySessionCoordinator.shared
    #if os(iOS)
        let artworkColorExtractor = ArtworkDominantColorExtractor.shared
    #endif

        Task { @MainActor in
            await mediaCacheStore.performMaintenance()
            searchCacheHintStore.performMaintenance()
            await spotifySessionCoordinator.restoreSessionIfNeeded()
//            await youtube.restoreSession()
        }

#if os(iOS)
        let playerViewModel = PlayerViewModel(
            youtube: youtube,
            settings: prefetchSettings,
            artworkVideoProcessor: artworkVideoProcessor,
            metadataCache: metadataCache,
            mediaCacheStore: mediaCacheStore,
            playbackMetricsStore: playbackMetricsStore,
            streamingProviderSettings: streamingProviderSettings,
            radioSessionStore: radioSessionStore,
            artworkColorExtractor: artworkColorExtractor
        )
#else
        let playerViewModel = PlayerViewModel(
            youtube: youtube,
            settings: prefetchSettings,
            artworkVideoProcessor: artworkVideoProcessor,
            metadataCache: metadataCache,
            mediaCacheStore: mediaCacheStore,
            playbackMetricsStore: playbackMetricsStore,
            streamingProviderSettings: streamingProviderSettings,
            radioSessionStore: radioSessionStore
        )
#endif

        let coreDomain = CoreDomain(
            streamingProviderSettings: streamingProviderSettings,
            prefetchSettings: prefetchSettings,
            networkMonitor: networkMonitor
        )

        let playbackDomain: PlaybackDomain
        #if os(iOS)
        playbackDomain = PlaybackDomain(
            playerViewModel: playerViewModel,
            playbackControlSettings: playbackControlSettings,
            playbackMetricsStore: playbackMetricsStore,
            systemVolumeController: SystemVolumeController.shared,
            volumeButtonSkipController: VolumeButtonSkipController.shared,
            radioSessionStore: radioSessionStore,
            artworkVideoProcessor: artworkVideoProcessor,
            artworkColorExtractor: artworkColorExtractor
        )
        #else
        playbackDomain = PlaybackDomain(
            playerViewModel: playerViewModel,
            playbackControlSettings: playbackControlSettings,
            playbackMetricsStore: playbackMetricsStore,
            radioSessionStore: radioSessionStore,
            artworkVideoProcessor: artworkVideoProcessor
        )
        #endif

        let searchDomain = SearchDomain(
            searchViewModel: SearchViewModel(
                youtube: youtube,
                settings: prefetchSettings,
                networkMonitor: networkMonitor,
                historyStore: historyStore,
                searchCacheHintStore: searchCacheHintStore,
                streamingProviderSettings: streamingProviderSettings,
                centralMediaStore: centralMediaStore,
                metadataCache: metadataCache,
                searchCache: searchCache
            ),
            historyStore: historyStore,
            searchCacheHintStore: searchCacheHintStore,
            searchCache: searchCache,
            suggestionRanker: SuggestionRanker.self
        )

        let libraryDomain = LibraryDomain(
            playlistLibraryStore: playlistLibraryStore,
            playlistImportJobStore: playlistImportJobStore,
            centralMediaStore: centralMediaStore,
            mediaCacheStore: mediaCacheStore,
            metadataCache: metadataCache
        )

        let userDomain = UserDomain(spotifySessionCoordinator: spotifySessionCoordinator)

        let appDomain = AppDomain(
            youtube: youtube,
            router: router,
            modelContainer: modelContainer
        )

        return ServicesContainer(
            core: coreDomain.interface,
            playback: playbackDomain.interface(streamingProviderSettings: streamingProviderSettings),
            search: searchDomain.interface(networkMonitor: networkMonitor, prefetchSettings: prefetchSettings),
            library: libraryDomain.interface,
            user: userDomain.interface,
            app: appDomain.interface
        )
    }

    private static func makeInMemoryDependencies(youtube: YouTube, router: Router, underlyingError: Error) -> ServicesContainer {
        let modelContainer: ModelContainer
        do {
            modelContainer = try makeModelContainer(configuration: ModelConfiguration(isStoredInMemoryOnly: true))
        } catch {
            preconditionFailure(
                "Bootstrap failed for persistent and in-memory stores. " +
                "persistent=\(underlyingError.localizedDescription) memory=\(error.localizedDescription)"
            )
        }

        return buildDependencies(youtube: youtube, router: router, modelContainer: modelContainer)
    }

    private static func makePersistentModelContainer() throws -> ModelContainer {
        let schema = Schema([
            SearchHistoryEntry.self,
            MediaCacheEntry.self,
            SearchCacheHintEntry.self,
            Playlist.self,
            PlaylistItem.self,
            PlaylistImportJobEntry.self,
            PlaylistImportTrackEntry.self,
            PlaylistImportCandidateEntry.self,
            Artist.self,
            Album.self,
            Song.self
        ])

        // Ensure Application Support directory exists
        let fileManager = FileManager.default
        if let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            try? fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
        }

        // Fallback to default configuration
        return try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: false)])
    }

    private static func makeModelContainer(configuration: ModelConfiguration? = nil) throws -> ModelContainer {
        let schema = Schema([
            SearchHistoryEntry.self,
            MediaCacheEntry.self,
            SearchCacheHintEntry.self,
            Playlist.self,
            PlaylistItem.self,
            PlaylistImportJobEntry.self,
            PlaylistImportTrackEntry.self,
            PlaylistImportCandidateEntry.self,
            Artist.self,
            Album.self,
            Song.self
        ])

        if let configuration {
            return try ModelContainer(for: schema, configurations: configuration)
        }

        return try ModelContainer(for: schema)
    }

}

