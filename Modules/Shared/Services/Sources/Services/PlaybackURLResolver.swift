import Foundation
import YouTubeSDK

/// Lightweight actor to pre-resolve and cache playable stream URLs (HLS preferred)
/// so UI components (Search / Player) can obtain a quick URL to start playback
/// while the full metadata resolution continues in the background.
public actor PlaybackURLResolver {
    @MainActor private static var _shared: PlaybackURLResolver?

    /// Obtain the shared resolver instance. This runs on the `MainActor` because
    /// it needs to access `YouTube.shared` safely and mutate the shared holder.
    public static func sharedInstance() async -> PlaybackURLResolver {
        return await MainActor.run {
            if let s = _shared { return s }
            let resolver = PlaybackURLResolver(youtube: YouTube.shared)
            _shared = resolver
            return resolver
        }
    }

    private let youtube: YouTube
    private var cache: [String: (url: URL, expiresAt: Date?)] = [:]
    private let cacheTTL: TimeInterval = 75 // seconds (match preparedYouTubeMaxAge)

    private init(youtube: YouTube) {
        self.youtube = youtube
    }

    /// Return a cached URL if present and not expired.
    public func cachedURL(for videoID: String) -> URL? {
        guard let entry = cache[videoID] else { return nil }
        if let expires = entry.expiresAt {
            if Date() >= expires { cache.removeValue(forKey: videoID); return nil }
        }
        return entry.url
    }

    /// Prewarm playback info for a list of video IDs. This fetches minimal data and caches
    /// the best candidate URL for quick startup (HLS preferred).
    public func prewarm(_ ids: [String]) async {
        guard !ids.isEmpty else { return }

        await withTaskGroup(of: Void.self) { group in
            for id in ids {
                group.addTask { [weak self] in
                    guard let self = self else { return }
                    _ = try? await self.resolve(videoID: id)
                }
            }
            await group.waitForAll()
        }
    }

    /// Resolve the best playable URL for a given video id. Will cache the result.
    public func resolve(videoID: String) async throws -> URL {
        if let cached = cachedURL(for: videoID) { return cached }

        // Fetch full video using the watch endpoint so playback avoids the old /player path.
        let video = try await youtube.main.video(id: videoID)

        // Prefer HLS
        if let hls = video.hlsURL {
            let expires = self.deriveExpiry(from: video, url: hls)
            cache[videoID] = (url: hls, expiresAt: expires)
            return hls
        }

        // Fallback to best audio or muxed
        if let audio = video.bestAudioStream, let urlString = audio.url, let url = URL(string: urlString) {
            let expires = self.deriveExpiry(from: video, url: url)
            cache[videoID] = (url: url, expiresAt: expires)
            return url
        }

        if let muxed = video.bestMuxedStream, let urlString = muxed.url, let url = URL(string: urlString) {
            let expires = self.deriveExpiry(from: video, url: url)
            cache[videoID] = (url: url, expiresAt: expires)
            return url
        }

        throw YouTubeError.decipheringFailed(videoId: videoID)
    }

    private func deriveExpiry(from video: YouTubeVideo, url: URL) -> Date? {
        // 1) If streamingData carries expiresInSeconds, use that
        if let expiresIn = video.streamingData?.expiresInSeconds,
           let seconds = Double(expiresIn) {
            let safe = max(0, seconds - 30)
            return Date().addingTimeInterval(safe)
        }

        // 2) Try query param heuristics: expire, expires, exp
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false), let items = components.queryItems {
            let keys = ["expire", "expires", "exp", "expiration"]
            for key in keys {
                if let value = items.first(where: { $0.name.caseInsensitiveCompare(key) == .orderedSame })?.value,
                   let numeric = Double(value) {
                    let seconds: Double
                    if numeric > 1_000_000_000_000 { seconds = numeric / 1000.0 } else { seconds = numeric }
                    return Date(timeIntervalSince1970: seconds).addingTimeInterval(-30)
                }
            }
        }

        // 3) Default to TTL
        return Date().addingTimeInterval(cacheTTL)
    }
}
