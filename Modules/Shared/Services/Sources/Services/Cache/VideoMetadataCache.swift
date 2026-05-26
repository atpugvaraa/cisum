import Foundation
import AVKit
import YouTubeSDK

extension YouTubeVideo: @unchecked Sendable {}

public actor VideoMetadataCache {
    public static let shared = VideoMetadataCache()

    public struct Entry: Sendable {
        public let video: YouTubeVideo
        public let resolvedURL: URL
        public let cachedAt: Date
        public let validUntil: Date
        public var lastAccessed: Date

        public var isExpired: Bool {
            Date() >= validUntil
        }
        
        public init(video: YouTubeVideo, resolvedURL: URL, cachedAt: Date, validUntil: Date, lastAccessed: Date) {
            self.video = video
            self.resolvedURL = resolvedURL
            self.cachedAt = cachedAt
            self.validUntil = validUntil
            self.lastAccessed = lastAccessed
        }
    }

    private static let defaultURLTTL: TimeInterval = 60 * 20

    private var store: [String: Entry] = [:]
    private var inFlight: [String: Task<Entry, Error>] = [:]
    private var lru: [String] = []
    @MainActor private var warmedItems: [String: AVPlayerItem] = [:]
    private let maxEntries: Int = 20

    public init() {}

    public func get(_ id: String, allowStale: Bool = true) -> Entry? {
        guard var entry = store[id] else { return nil }
        if !allowStale, entry.isExpired {
            return nil
        }
        entry.lastAccessed = Date()
        store[id] = entry
        touch(id)
        return entry
    }

    public func set(_ id: String, video: YouTubeVideo) throws {
        guard let url = Self.resolvePlayableURL(from: video) else {
            throw CacheError.decipheringFailed(videoId: id)
        }

        let cachedAt = Date()
        let entry = Entry(
            video: video,
            resolvedURL: url,
            cachedAt: cachedAt,
            validUntil: Self.resolveValidUntilDate(from: video, cachedAt: cachedAt),
            lastAccessed: cachedAt
        )

        store[id] = entry
        touch(id)
        Task {
            await evictIfNeeded()
        }
    }

    public func resolve(
        id: String,
        metricsEnabled: Bool = true,
        fetcher: @Sendable @escaping (String) async throws -> YouTubeVideo
    ) async throws -> Entry {
        let startedAt = Date()
        if let cached = get(id, allowStale: false) {
            if metricsEnabled {
                let elapsed = Date().timeIntervalSince(startedAt) * 1000
                await PlaybackMetricsStore.shared.recordResolve(cacheHit: true, durationMs: elapsed)
            }
            return cached
        }

        // Drop stale URL-bearing entries before re-resolve to reduce 403/permission failures.
        if store[id] != nil {
            store[id] = nil
            let staleID = id
            await MainActor.run {
                warmedItems[staleID] = nil
            }
            lru.removeAll { $0 == id }
        }

        if let task = inFlight[id] {
            return try await task.value
        }

        let task = Task<Entry, Error> {
            let video = try await fetcher(id)
            guard let url = Self.resolvePlayableURL(from: video) else {
                throw CacheError.decipheringFailed(videoId: id)
            }

            let cachedAt = Date()
            return Entry(
                video: video,
                resolvedURL: url,
                cachedAt: cachedAt,
                validUntil: Self.resolveValidUntilDate(from: video, cachedAt: cachedAt),
                lastAccessed: cachedAt
            )
        }

        inFlight[id] = task

        do {
            let entry = try await task.value
            store[id] = entry
            touch(id)
            await evictIfNeeded()
            inFlight[id] = nil
            if metricsEnabled {
                let elapsed = Date().timeIntervalSince(startedAt) * 1000
                await PlaybackMetricsStore.shared.recordResolve(cacheHit: false, durationMs: elapsed)
            }
            return entry
        } catch {
            inFlight[id] = nil
            throw error
        }
    }

    public nonisolated func prefetch(
        ids: [String],
        maxConcurrent: Int,
        mode: PrefetchModeOverride,
        metricsEnabled: Bool = true,
        fetcher: @Sendable @escaping (String) async throws -> YouTubeVideo
    ) async {
        let unique = Array(Set(ids)).filter { !($0.isEmpty) }
        guard !unique.isEmpty else { return }
        let limit = max(1, maxConcurrent)
        var nextIndex = 0

        await withTaskGroup(of: Void.self) { group in
            func enqueueNext() {
                guard nextIndex < unique.count else { return }
                let id = unique[nextIndex]
                nextIndex += 1
                group.addTask { [self, id, metricsEnabled, fetcher, mode] in
                    if let entry = try? await self.resolve(id: id, metricsEnabled: metricsEnabled, fetcher: fetcher),
                       mode == .aggressiveWarmup {
                        await self.warmupItem(for: id, url: entry.resolvedURL)
                    }
                }
            }

            for _ in 0..<min(limit, unique.count) {
                enqueueNext()
            }

            while let _ = await group.next() {
                enqueueNext()
            }
        }
    }

    public func warmedItem(for id: String) async -> AVPlayerItem? {
        await MainActor.run {
            warmedItems[id]
        }
    }

    public func remove(_ id: String) {
        store[id] = nil
        inFlight[id]?.cancel()
        inFlight[id] = nil
        lru.removeAll { $0 == id }
        let staleID = id
        Task {
            await MainActor.run {
                warmedItems[staleID] = nil
            }
        }
    }

    public func clear() {
        store.removeAll()
        for (_, task) in inFlight {
            task.cancel()
        }
        inFlight.removeAll()
        lru.removeAll()
        Task {
            await MainActor.run {
                warmedItems.removeAll()
            }
        }
    }

    private func touch(_ id: String) {
        lru.removeAll { $0 == id }
        lru.insert(id, at: 0)
    }

    private func evictIfNeeded() async {
        while lru.count > maxEntries, let last = lru.last {
            store[last] = nil
            let staleID = last
            await MainActor.run {
                warmedItems[staleID] = nil
            }
            lru.removeLast()
        }
    }

    private func warmupItem(for id: String, url: URL) async {
        let item = AVPlayerItem(url: url)
        item.preferredForwardBufferDuration = 8
        await MainActor.run {
            warmedItems[id] = item
        }
    }


    private static func resolvePlayableURL(from video: YouTubeVideo) -> URL? {
        // 1) Audio-only stream (ideal for music)
        if let audio = video.bestAudioStream,
           let urlString = audio.playbackUrl,
           let url = URL(string: urlString) {
            return url
        }

        // 2) Muxed stream (video + audio in one container)
        if let muxed = video.bestMuxedStream,
              let urlString = muxed.playbackUrl,
           let url = URL(string: urlString) {
            return url
        }

        // 3) HLS manifest
        if let hls = video.hlsURL {
            return hls
        }

        // 4) Fallback: use the first adaptive format with a URL
        //    (covers videos where YouTube returns only video-only streams)
        if let first = video.streamingData?.adaptiveFormats.first,
              let urlString = first.playbackUrl,
           let url = URL(string: urlString) {
            return url
        }

        return nil
    }


    private static func resolveValidUntilDate(from url: URL, cachedAt: Date) -> Date {
        if let expirationDate = resolveURLExpiration(from: url) {
            return expirationDate.addingTimeInterval(-30)
        }

        return cachedAt.addingTimeInterval(defaultURLTTL)
    }

    private static func resolveValidUntilDate(from video: YouTubeVideo, cachedAt: Date) -> Date {
        if let expiresInSeconds = video.streamingData?.expiresInSeconds,
           let seconds = Double(expiresInSeconds) {
            return cachedAt.addingTimeInterval(max(0, seconds - 30))
        }

        if let url = resolvePlayableURL(from: video) {
            return resolveValidUntilDate(from: url, cachedAt: cachedAt)
        }

        return cachedAt.addingTimeInterval(defaultURLTTL)
    }

    private static func resolveURLExpiration(from url: URL) -> Date? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return nil
        }

        let expiryKeys = ["expire", "expires", "exp", "expiration"]
        for key in expiryKeys {
            guard let value = queryItems.first(where: { $0.name.caseInsensitiveCompare(key) == .orderedSame })?.value,
                  let numericValue = Double(value) else {
                continue
            }

            let seconds = numericValue > 1_000_000_000_000 ? numericValue / 1000.0 : numericValue
            return Date(timeIntervalSince1970: seconds)
        }

        return nil
    }

    public enum CacheError: Error {
        case decipheringFailed(videoId: String)
    }
}
