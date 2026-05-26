import Foundation
import Models
import ProviderSDK

public struct ProviderSDKStreamResolver: StreamResolutionProvider {
    private let providerSDK: ProviderSDK
    
    public init(providerSDK: ProviderSDK) {
        self.providerSDK = providerSDK
    }
    
    public func resolveStream(
        mediaID: String,
        title: String,
        artist: String,
        representations: [TrackRepresentation]? = nil,
        forceDecipher: Bool
    ) async throws -> [PlaybackCandidate] {
        var matchedTrack: Track?
        
        // 1. If representations are provided, construct a Track directly
        if let reps = representations, !reps.isEmpty {
            let unknownArtist = Artist(id: ArtistIdentifier(provider: "unknown", value: "unknown"), name: artist)
            let unknownAlbum = Album(id: AlbumIdentifier(provider: "unknown", value: "unknown"), title: "Unknown", artist: unknownArtist)
            
            matchedTrack = Track(
                id: CanonicalID.from(hash: mediaID),
                title: title,
                artists: [unknownArtist],
                album: unknownAlbum,
                duration: 0,
                representations: reps
            )
        } else {
            // 2. Fallback: Search across federation to find the track representation
            let query = "\(title) \(artist)"
            let searchStream = await providerSDK.searchTracks(query: query, limit: 1)
            
            for try await batch in searchStream {
                if let first = batch.first {
                    matchedTrack = first
                    break
                }
            }
        }
        
        guard let track = matchedTrack else {
            throw NSError(domain: "ProviderSDKStreamResolver", code: 404, userInfo: [NSLocalizedDescriptionKey: "Track not found across providers for: \(title) \(artist)"])
        }
        
        // 3. Resolve highest available stream
        let audioStream = try await providerSDK.resolveStream(for: track, quality: .high)
        
        let ext = audioStream.url.pathExtension.lowercased()
        let streamKind: PlaybackCandidate.StreamKind = ext == "m3u8" ? .hls : .muxed
        
        let candidate = PlaybackCandidate(
            url: audioStream.url,
            streamKind: streamKind,
            mimeType: nil,
            itag: nil,
            expiresAt: audioStream.expiresAt,
            isCompatible: true
        )
        
        return [candidate]
    }
    
    public func cachedURL(for mediaID: String) async -> URL? {
        // ProviderSDK URLs are often signed and ephemeral, relying on fast-cache is risky.
        // For now, defer to downstream resolvers.
        return nil
    }
}
