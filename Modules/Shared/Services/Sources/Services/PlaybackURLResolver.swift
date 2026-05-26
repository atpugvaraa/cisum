import Foundation
import YouTubeSDK
import ProviderSDK
import Models

/// Lightweight actor to pre-resolve and cache playable stream URLs (HLS preferred)
/// so UI components (Search / Player) can obtain a quick URL to start playback
/// while the full metadata resolution continues in the background.
public actor PlaybackURLResolver {
    @MainActor private static var _shared: PlaybackURLResolver?

    public static func sharedInstance() async -> PlaybackURLResolver {
        return await MainActor.run {
            if let s = _shared { return s }
            let resolver = PlaybackURLResolver(providers: [])
            _shared = resolver
            return resolver
        }
    }
    
    @MainActor
    public static func configureShared(providers: [StreamResolutionProvider]) {
        _shared = PlaybackURLResolver(providers: providers)
    }

    private let providers: [StreamResolutionProvider]

    public init(providers: [StreamResolutionProvider]) {
        self.providers = providers
    }

    public func cachedURL(for videoID: String) async -> URL? {
        for provider in providers {
            if let url = await provider.cachedURL(for: videoID) {
                return url
            }
        }
        return nil
    }

    /// Prewarm playback info for a list of video IDs. This fetches minimal data and caches
    /// the best candidate URL for quick startup (HLS preferred).
    /// Uses bounded concurrency (max 2) to avoid flooding YouTube with player requests.
    public func prewarm(_ ids: [String], title: String = "", artist: String = "") async {
        guard !ids.isEmpty else { return }

        await withThrowingTaskGroup(of: Void.self) { group in
            var submitted = 0
            let maxConcurrent = 2
            for id in ids {
                if submitted >= maxConcurrent {
                    try? await group.next()
                    submitted -= 1
                }
                group.addTask { [weak self] in
                    guard let self = self else { return }
                    _ = try? await self.resolve(mediaID: id, title: title, artist: artist)
                }
                submitted += 1
            }
        }
    }

    public func resolve(mediaID: String, title: String, artist: String, representations: [TrackRepresentation]? = nil, forceDecipher: Bool = false) async throws -> [PlaybackCandidate] {
        if !forceDecipher {
            if let cached = await cachedURL(for: mediaID) {
                let streamKind: PlaybackCandidate.StreamKind = cached.pathExtension.lowercased() == "m3u8" ? .hls : .muxed
                return [PlaybackCandidate(url: cached, streamKind: streamKind, mimeType: nil, itag: nil, expiresAt: Date().addingTimeInterval(3600), isCompatible: true)]
            }
        }

        var lastError: Error?
        for provider in providers {
            do {
                let candidates = try await provider.resolveStream(
                    mediaID: mediaID,
                    title: title,
                    artist: artist,
                    representations: representations,
                    forceDecipher: forceDecipher
                )
                if !candidates.isEmpty {
                    return candidates
                }
            } catch {
                lastError = error
                print("PlaybackURLResolver: Provider \(type(of: provider)) failed to resolve \(mediaID): \(error)")
                continue
            }
        }

        throw lastError ?? ResolverError.resolutionFailed(mediaID: mediaID)
    }

    enum ResolverError: Error {
        case resolutionFailed(mediaID: String)
    }

    // Removed deriveExpiry logic as it's now handled by the resolvers
}
