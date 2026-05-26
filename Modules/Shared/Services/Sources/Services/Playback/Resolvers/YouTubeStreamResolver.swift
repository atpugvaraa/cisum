import Foundation
import Models
import YouTubeSDK
import ProviderSDK
import Services

public struct YouTubeStreamResolver: StreamResolutionProvider {
    private let youtube: YouTube
    private let mediaCacheStore: MediaCacheStore
    private let metadataCache: any VideoMetadataCaching
    
    public init(
        youtube: YouTube,
        mediaCacheStore: MediaCacheStore,
        metadataCache: any VideoMetadataCaching
    ) {
        self.youtube = youtube
        self.mediaCacheStore = mediaCacheStore
        self.metadataCache = metadataCache
    }
    
    public func resolveStream(
        mediaID: String,
        title: String,
        artist: String,
        representations: [TrackRepresentation]?,
        forceDecipher: Bool
    ) async throws -> [PlaybackCandidate] {
        let normalizedMediaID = canonicalPlaybackMediaID(mediaID)
        let youtubeClient = await self.youtube.main
        
        // 1. Try Direct Smart Resolution first (Fast, <1s)
        if !forceDecipher {
            do {
                let video = try await youtubeClient.video(id: normalizedMediaID)
                let candidates = PlaybackCandidateBuilder.fromVideo(video, preferredURL: nil, validUntil: nil)
                
                // If we got a natively playable HLS manifest, return it immediately.
                if candidates.contains(where: { $0.streamKind == .hls }) {
                    await mediaCacheStore.savePlaybackResolution(mediaID: normalizedMediaID, candidates: candidates, validUntil: nil)
                    return candidates
                }
            } catch {
                print("YouTubeStreamResolver: fast resolution failed for \(normalizedMediaID): \(error.localizedDescription)")
            }
        }

        // 2. High-Quality Fallback: WebView HLS Extraction (The SmartTube 'Golden Path')
        // We use this if forceDecipher is requested (e.g. after a 403) or if fast resolution failed.
        print("YouTubeStreamResolver: triggering high-quality WebView extraction for \(normalizedMediaID)")
        if let webViewURL = await YouTubeWebViewHLSExtractor.shared.extractHLSURL(videoId: normalizedMediaID) {
            let candidate = PlaybackCandidate(
                url: webViewURL,
                headers: ["User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15"],
                streamKind: .hls,
                mimeType: "application/x-mpegURL",
                itag: nil,
                expiresAt: Date().addingTimeInterval(3600 * 4),
                isCompatible: true
            )
            await mediaCacheStore.savePlaybackResolution(mediaID: normalizedMediaID, candidates: [candidate], validUntil: nil)
            return [candidate]
        }

        // 3. Last Resort Fallback: Search-to-Stream
        if !title.isEmpty && !artist.isEmpty {
            do {
                let query = "\(title) \(artist)"
                let searchResults = try await youtube.music.search(query)
                if let firstResult = searchResults.first {
                    let video = try await youtubeClient.video(id: firstResult.videoId)
                    let candidates = PlaybackCandidateBuilder.fromVideo(video, preferredURL: nil, validUntil: nil)
                    if !candidates.isEmpty {
                        await mediaCacheStore.savePlaybackResolution(mediaID: normalizedMediaID, candidates: candidates, validUntil: nil)
                        return candidates
                    }
                }
            } catch {
                print("YouTubeStreamResolver: search-to-stream failed: \(error.localizedDescription)")
            }
        }
        
        throw ResolverError.decipheringFailed(videoId: normalizedMediaID)
    }
    
    enum ResolverError: Error {
        case decipheringFailed(videoId: String)
    }
    
    public func cachedURL(for mediaID: String) async -> URL? {
        let normalizedMediaID = canonicalPlaybackMediaID(mediaID)
        let candidates = await mediaCacheStore.playbackCandidates(for: normalizedMediaID, maxAge: 21600)
        return candidates?.first { $0.isCompatible }?.url
    }
    
    private func canonicalPlaybackMediaID(_ mediaID: String) -> String {
        let trimmed = mediaID.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("youtube-") {
            return String(trimmed.dropFirst("youtube-".count))
        }
        return trimmed
    }
}
