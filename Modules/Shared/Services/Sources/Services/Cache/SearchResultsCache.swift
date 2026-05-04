import Foundation
import YouTubeSDK
import Utilities

@MainActor
public final class SearchResultsCache {
    public static let shared = SearchResultsCache()

    public struct Lookup<Value>: Sendable where Value: Sendable {
        public let results: [Value]
        public let isStale: Bool
        
        public init(results: [Value], isStale: Bool) {
            self.results = results
            self.isStale = isStale
        }
    }

    public struct MusicEntry: Sendable {
        public let results: [YouTubeMusicSong]
        public let cachedAt: Date
        
        public init(results: [YouTubeMusicSong], cachedAt: Date) {
            self.results = results
            self.cachedAt = cachedAt
        }
    }

    public struct VideoEntry: Sendable {
        public let results: [YouTubeSearchResult]
        public let cachedAt: Date
        
        public init(results: [YouTubeSearchResult], cachedAt: Date) {
            self.results = results
            self.cachedAt = cachedAt
        }
    }

    private var musicStore: [String: MusicEntry] = [:]
    private var videoStore: [String: VideoEntry] = [:]
    private var musicLRU: [String] = []
    private var videoLRU: [String] = []
    private let musicMax: Int = 50
    private let videoMax: Int = 50
    private let ttl: TimeInterval = 300 // 5 minutes

    public init() {}

    public func getMusicResults(for query: String) -> Lookup<YouTubeMusicSong>? {
        let key = normalized(query)
        guard let entry = musicStore[key] else { return nil }
        touchMusic(key)
        return Lookup(results: entry.results, isStale: Date().timeIntervalSince(entry.cachedAt) > ttl)
    }

    public func setMusicResults(_ results: [YouTubeMusicSong], for query: String) {
        let key = normalized(query)
        musicStore[key] = MusicEntry(results: results, cachedAt: Date())
        touchMusic(key)
        evictMusicIfNeeded()
    }

    public func getVideoResults(for query: String) -> Lookup<YouTubeSearchResult>? {
        let key = normalized(query)
        guard let entry = videoStore[key] else { return nil }
        touchVideo(key)
        return Lookup(results: entry.results, isStale: Date().timeIntervalSince(entry.cachedAt) > ttl)
    }

    public func setVideoResults(_ results: [YouTubeSearchResult], for query: String) {
        let key = normalized(query)
        videoStore[key] = VideoEntry(results: results, cachedAt: Date())
        touchVideo(key)
        evictVideoIfNeeded()
    }

    public func clear() {
        musicStore.removeAll()
        videoStore.removeAll()
        musicLRU.removeAll()
        videoLRU.removeAll()
    }

    private func touchMusic(_ q: String) {
        guard musicLRU.first != q else { return }
        if let idx = musicLRU.firstIndex(of: q) {
            musicLRU.remove(at: idx)
        }
        musicLRU.insert(q, at: 0)
    }

    private func touchVideo(_ q: String) {
        guard videoLRU.first != q else { return }
        if let idx = videoLRU.firstIndex(of: q) {
            videoLRU.remove(at: idx)
        }
        videoLRU.insert(q, at: 0)
    }

    private func evictMusicIfNeeded() {
        while musicLRU.count > musicMax, let last = musicLRU.last {
            musicStore[last] = nil
            musicLRU.removeLast()
        }
    }

    private func evictVideoIfNeeded() {
        while videoLRU.count > videoMax, let last = videoLRU.last {
            videoStore[last] = nil
            videoLRU.removeLast()
        }
    }

    private func normalized(_ query: String) -> String {
        query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
