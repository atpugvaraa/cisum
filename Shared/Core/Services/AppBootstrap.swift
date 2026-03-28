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
    static func makeDependencies(youtube: YouTube) throws -> AppBootstrapDependencies {
        prepareSharedApplicationSupportDirectory()

        let modelContainer = try ModelContainer(for: SearchHistoryEntry.self)
        let prefetchSettings = PrefetchSettings.shared
        let networkMonitor = NetworkPathMonitor.shared
        let historyStore = SearchHistoryStore(context: ModelContext(modelContainer))

        restoreCookies(into: youtube)

        return AppBootstrapDependencies(
            modelContainer: modelContainer,
            prefetchSettings: prefetchSettings,
            networkMonitor: networkMonitor,
            playerViewModel: PlayerViewModel(youtube: youtube, settings: prefetchSettings),
            searchViewModel: SearchViewModel(
                youtube: youtube,
                settings: prefetchSettings,
                networkMonitor: networkMonitor,
                historyStore: historyStore
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
