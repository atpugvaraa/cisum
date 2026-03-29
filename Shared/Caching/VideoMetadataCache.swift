import Foundation
import AVKit
import YouTubeSDK

actor VideoMetadataCache {
    static let shared = VideoMetadataCache()

    struct Entry {
        let video: YouTubeVideo
        let resolvedURL: URL
        let cachedAt: Date
        let validUntil: Date
        var lastAccessed: Date

        var isExpired: Bool {
            Date() >= validUntil
        }
    }

    private static let defaultURLTTL: TimeInterval = 60 * 20

    private var store: [String: Entry] = [:]
    private var inFlight: [String: Task<Entry, Error>] = [:]
    private var lru: [String] = []
    private var warmedItems: [String: AVPlayerItem] = [:]
    private let maxEntries: Int = 20

    init() {}

    func get(_ id: String, allowStale: Bool = true) -> Entry? {
        guard var entry = store[id] else { return nil }
        if !allowStale, entry.isExpired {
            return nil
        }
        entry.lastAccessed = Date()
        store[id] = entry
        touch(id)
        return entry
    }

    func set(_ id: String, video: YouTubeVideo) throws {
        guard let url = Self.resolvePlayableURL(from: video) else {
            throw YouTubeError.decipheringFailed(videoId: id)
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
        evictIfNeeded()
    }

    func resolve(
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
            warmedItems[id] = nil
            lru.removeAll { $0 == id }
        }

        if let task = inFlight[id] {
            return try await task.value
        }

        let task = Task<Entry, Error> {
            let video = try await fetcher(id)
            guard let url = Self.resolvePlayableURL(from: video) else {
                throw YouTubeError.decipheringFailed(videoId: id)
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
            evictIfNeeded()
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

    func prefetch(
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
                group.addTask {
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

    func warmedItem(for id: String) -> AVPlayerItem? {
        warmedItems[id]
    }

    func remove(_ id: String) {
        store[id] = nil
        inFlight[id]?.cancel()
        inFlight[id] = nil
        lru.removeAll { $0 == id }
    }

    func clear() {
        store.removeAll()
        for (_, task) in inFlight {
            task.cancel()
        }
        inFlight.removeAll()
        lru.removeAll()
    }

    private func touch(_ id: String) {
        lru.removeAll { $0 == id }
        lru.insert(id, at: 0)
    }

    private func evictIfNeeded() {
        while lru.count > maxEntries, let last = lru.last {
            store[last] = nil
            warmedItems[last] = nil
            lru.removeLast()
        }
    }

    private func warmupItem(for id: String, url: URL) {
        let item = AVPlayerItem(url: url)
        item.preferredForwardBufferDuration = 8
        warmedItems[id] = item
    }

    private static func resolvePlayableURL(from video: YouTubeVideo) -> URL? {
        if let audio = video.bestAudioStream,
           let urlString = audio.url,
           let url = URL(string: urlString) {
            return url
        }

        if let muxed = video.bestMuxedStream,
           let urlString = muxed.url,
           let url = URL(string: urlString) {
            return url
        }

        if let hls = video.hlsURL {
            return hls
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
}
