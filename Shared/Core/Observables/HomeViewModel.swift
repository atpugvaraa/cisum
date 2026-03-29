//
//  HomeViewModel.swift
//  cisum
//
//  Created by GitHub Copilot on 29/03/26.
//

import Foundation
import Observation
import YouTubeSDK

@Observable
@MainActor
final class HomeViewModel {
    private enum Pagination {
        static let threshold = 8
        static let maxPages = 4
        static let cooldown: TimeInterval = 0.35
    }

    private var youtube: YouTube = .shared
    private var continuationToken: String?
    private var loadedContinuationPages = 0
    private var seenItemKeys = Set<String>()
    private var lastPaginationTriggerAt: Date?
    private var lastPaginationTriggerToken: String?

    var items: [HomeFeedItem] = []
    var isLoading = false
    var isLoadingMore = false
    var didLoadInitialFeed = false
    var errorMessage: String?
    var footerMessage: String?

    var canLoadMore: Bool {
        continuationToken != nil && loadedContinuationPages < Pagination.maxPages
    }

    func configure(youtube: YouTube) {
        self.youtube = youtube
    }

    func loadIfNeeded() async {
        guard !didLoadInitialFeed else { return }
        await loadInitialFeed(force: false)
    }

    func refresh() async {
        await loadInitialFeed(force: true)
    }

    func loadMoreIfNeeded(currentIndex: Int, totalCount: Int) {
        guard totalCount > 0 else { return }
        let triggerIndex = max(totalCount - Pagination.threshold, 0)
        guard currentIndex >= triggerIndex else { return }
        guard canLoadMore else {
            if loadedContinuationPages >= Pagination.maxPages {
                footerMessage = "Showing the latest music recommendations for now."
            }
            return
        }
        guard !isLoadingMore else { return }

        if let token = continuationToken,
           let lastTime = lastPaginationTriggerAt,
           lastPaginationTriggerToken == token,
           Date().timeIntervalSince(lastTime) < Pagination.cooldown {
            return
        }

        lastPaginationTriggerAt = Date()
        lastPaginationTriggerToken = continuationToken

        Task {
            await loadMore()
        }
    }

    private func loadInitialFeed(force: Bool) async {
        if isLoading { return }
        if didLoadInitialFeed && !force { return }

        isLoading = true
        errorMessage = nil
        if force {
            footerMessage = nil
            loadedContinuationPages = 0
            continuationToken = nil
            seenItemKeys.removeAll(keepingCapacity: true)
        }

        defer {
            isLoading = false
            didLoadInitialFeed = true
        }

        var mergedItems: [HomeFeedItem] = []
        var latestError: Error?

        async let musicSectionsResult = fetchMusicSections()
        async let mainHomeResult = fetchMainHomeContinuation()

        switch await musicSectionsResult {
        case .success(let musicSections):
            mergedItems.append(contentsOf: mapMusicSections(musicSections))
        case .failure(let error):
            latestError = error
        }

        switch await mainHomeResult {
        case .success(let homeContinuation):
            continuationToken = homeContinuation.continuationToken
            mergedItems.append(contentsOf: mapMainItems(homeContinuation.items))
        case .failure(let error):
            continuationToken = nil
            latestError = latestError ?? error
        }

        let hasItems = mergeItems(mergedItems, replacing: true)

        if !hasItems {
            errorMessage = latestError?.localizedDescription ?? "No music items were returned from Home."
            footerMessage = nil
            return
        }

        if continuationToken == nil {
            footerMessage = "No more Home pages are available right now."
        }
    }

    private func fetchMusicSections() async -> Result<[YouTubeMusicSection], Error> {
        do {
            let sections = try await youtube.music.getHome()
            return .success(sections)
        } catch {
            return .failure(error)
        }
    }

    private func fetchMainHomeContinuation() async -> Result<YouTubeContinuation<YouTubeItem>, Error> {
        do {
            let continuation = try await youtube.main.getHome()
            return .success(continuation)
        } catch {
            return .failure(error)
        }
    }

    private func loadMore() async {
        guard let token = continuationToken, !token.isEmpty else {
            footerMessage = "You're all caught up."
            return
        }
        guard loadedContinuationPages < Pagination.maxPages else {
            footerMessage = "Showing the latest music recommendations for now."
            return
        }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let continuation = try await youtube.main.fetchContinuation(token: token)
            continuationToken = continuation.continuationToken
            loadedContinuationPages += 1

            let appended = mergeItems(mapMainItems(continuation.items), replacing: false)
            if !appended && continuationToken == nil {
                footerMessage = "You're all caught up."
            }

            if loadedContinuationPages >= Pagination.maxPages {
                footerMessage = "Showing the latest music recommendations for now."
            }
        } catch {
            continuationToken = nil
            if items.isEmpty {
                errorMessage = error.localizedDescription
            } else {
                footerMessage = "Unable to load more Home items right now."
            }
        }
    }

    private func mapMusicSections(_ sections: [YouTubeMusicSection]) -> [HomeFeedItem] {
        sections.flatMap(\.items).compactMap { item in
            switch item {
            case .song(let song):
                return .musicSong(song)
            case .album(let album):
                return .musicAlbum(album)
            case .artist(let artist):
                return .musicArtist(artist)
            case .playlist(let playlist):
                return .musicPlaylist(playlist)
            }
        }
    }

    private func mapMainItems(_ sourceItems: [YouTubeItem]) -> [HomeFeedItem] {
        sourceItems
            .filter { shouldKeepMusicHomeItem($0) }
            .map { HomeFeedItem.main($0) }
    }

    @discardableResult
    private func mergeItems(_ incomingItems: [HomeFeedItem], replacing: Bool) -> Bool {
        if replacing {
            items.removeAll(keepingCapacity: true)
            seenItemKeys.removeAll(keepingCapacity: true)
        }

        var appended = false
        for item in incomingItems {
            let key = item.stableKey
            if seenItemKeys.insert(key).inserted {
                items.append(item)
                appended = true
            }
        }

        return appended
    }
}

enum HomeFeedItem: Identifiable {
    case musicSong(YouTubeMusicSong)
    case musicAlbum(YouTubeMusicAlbum)
    case musicArtist(YouTubeMusicArtist)
    case musicPlaylist(YouTubeMusicPlaylist)
    case main(YouTubeItem)

    var id: String {
        stableKey
    }

    var stableKey: String {
        switch self {
        case .musicSong(let song):
            return "media:\(song.videoId)"
        case .musicAlbum(let album):
            return "album:\(album.id)"
        case .musicArtist(let artist):
            return "artist:\(artist.id)"
        case .musicPlaylist(let playlist):
            return "playlist:\(playlist.id)"
        case .main(let item):
            switch item {
            case .video(let video):
                return "media:\(video.id)"
            case .song(let song):
                return "media:\(song.videoId)"
            case .playlist(let playlist):
                return "playlist:\(playlist.id)"
            case .channel(let channel):
                return "channel:\(channel.id)"
            case .shelf(let shelf):
                return "shelf:\(shelf.title.lowercased())"
            }
        }
    }
}
