//
//  AppBootstrap.swift
//  cisum
//
//  Created by Codex on 28/03/26.
//

import Foundation
import SwiftData
import YouTubeSDK

struct AppBootstrapDependencies {
    let modelContainer: ModelContainer
    let prefetchSettings: PrefetchSettings
    let networkMonitor: NetworkPathMonitor
    let playerViewModel: PlayerViewModel
    let searchViewModel: SearchViewModel
}

enum AppBootstrap {
    static func makeDependenciesOrFallback(youtube: YouTube) -> AppBootstrapDependencies {
        do {
            return try makeDependencies(youtube: youtube)
        } catch {
            assertionFailure("Persistent bootstrap failed: \(error.localizedDescription). Falling back to in-memory dependencies.")
            return makeInMemoryDependencies(youtube: youtube, underlyingError: error)
        }
    }

    static func makeDependencies(youtube: YouTube) throws -> AppBootstrapDependencies {
        prepareSharedApplicationSupportDirectory()

        let modelContainer = try ModelContainer(
            for: SearchHistoryEntry.self,
            MediaCacheEntry.self,
            SearchCacheHintEntry.self
        )
        let prefetchSettings = PrefetchSettings.shared
        let networkMonitor = NetworkPathMonitor.shared
        let modelContext = ModelContext(modelContainer)
        let historyStore = SearchHistoryStore(context: modelContext)
        let mediaCacheStore = MediaCacheStore(context: modelContext)
        let searchCacheHintStore = SearchCacheHintStore(context: modelContext)
        let artworkVideoProcessor = ArtworkVideoProcessor.shared

        Task { @MainActor in
            await mediaCacheStore.performMaintenance()
            searchCacheHintStore.performMaintenance()
        }

        restoreCookies(into: youtube)

        return AppBootstrapDependencies(
            modelContainer: modelContainer,
            prefetchSettings: prefetchSettings,
            networkMonitor: networkMonitor,
            playerViewModel: PlayerViewModel(
                youtube: youtube,
                settings: prefetchSettings,
                artworkVideoProcessor: artworkVideoProcessor,
                mediaCacheStore: mediaCacheStore
            ),
            searchViewModel: SearchViewModel(
                youtube: youtube,
                settings: prefetchSettings,
                networkMonitor: networkMonitor,
                historyStore: historyStore,
                searchCacheHintStore: searchCacheHintStore
            )
        )
    }

    private static func makeInMemoryDependencies(youtube: YouTube, underlyingError: Error) -> AppBootstrapDependencies {
        let modelContainer: ModelContainer
        do {
            let memoryConfiguration = ModelConfiguration(isStoredInMemoryOnly: true)
            modelContainer = try ModelContainer(
                for: SearchHistoryEntry.self,
                MediaCacheEntry.self,
                SearchCacheHintEntry.self,
                configurations: memoryConfiguration
            )
        } catch {
            preconditionFailure(
                "Bootstrap failed for persistent and in-memory stores. " +
                "persistent=\(underlyingError.localizedDescription) memory=\(error.localizedDescription)"
            )
        }

        let prefetchSettings = PrefetchSettings.shared
        let networkMonitor = NetworkPathMonitor.shared
        let modelContext = ModelContext(modelContainer)
        let historyStore = SearchHistoryStore(context: modelContext)
        let mediaCacheStore = MediaCacheStore(context: modelContext)
        let searchCacheHintStore = SearchCacheHintStore(context: modelContext)
        let artworkVideoProcessor = ArtworkVideoProcessor.shared

        Task { @MainActor in
            await mediaCacheStore.performMaintenance()
            searchCacheHintStore.performMaintenance()
        }

        restoreCookies(into: youtube)

        return AppBootstrapDependencies(
            modelContainer: modelContainer,
            prefetchSettings: prefetchSettings,
            networkMonitor: networkMonitor,
            playerViewModel: PlayerViewModel(
                youtube: youtube,
                settings: prefetchSettings,
                artworkVideoProcessor: artworkVideoProcessor,
                mediaCacheStore: mediaCacheStore
            ),
            searchViewModel: SearchViewModel(
                youtube: youtube,
                settings: prefetchSettings,
                networkMonitor: networkMonitor,
                historyStore: historyStore,
                searchCacheHintStore: searchCacheHintStore
            )
        )
    }

    private static func prepareSharedApplicationSupportDirectory() {
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.aaravgupta.cisum"
        ) else {
            return
        }

        let appSupportURL = groupURL.appendingPathComponent("Library/Application Support")
        do {
            try FileManager.default.createDirectory(
                at: appSupportURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            // Non-fatal: if creation fails, ModelContainer will attempt recovery.
        }
    }

    private static func restoreCookies(into youtube: YouTube) {
        if let cookieString = Keychain.load(key: "user_cookies") {
            youtube.cookies = cookieString
        }
    }
}
