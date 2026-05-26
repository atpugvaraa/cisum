import Foundation
import Models
import YouTubeSDK
import SpotifySDK

public struct HybridRadioProvider: RadioEngineProvider {
    private let spotifyProvider: SpotifyRadioProvider
    private let youtubeProvider: YouTubeRadioProvider
    
    public init(spotifyProvider: SpotifyRadioProvider, youtubeProvider: YouTubeRadioProvider) {
        self.spotifyProvider = spotifyProvider
        self.youtubeProvider = youtubeProvider
    }
    
    public func generateNextBatch(
        seedMediaID: String,
        seedTitle: String,
        seedArtist: String,
        continuationToken: String?
    ) async throws -> (tracks: [RadioEngineTrack], nextContinuationToken: String?) {
        
        // Fetch from both concurrently
        async let spotifyResult = try? spotifyProvider.generateNextBatch(
            seedMediaID: seedMediaID,
            seedTitle: seedTitle,
            seedArtist: seedArtist,
            continuationToken: nil
        )
        
        async let youtubeResult = try? youtubeProvider.generateNextBatch(
            seedMediaID: seedMediaID,
            seedTitle: seedTitle,
            seedArtist: seedArtist,
            continuationToken: continuationToken
        )
        
        let (sRes, yRes) = await (spotifyResult, youtubeResult)
        
        var combined: [RadioEngineTrack] = []
        var sTracks = sRes?.tracks ?? []
        var yTracks = yRes?.tracks ?? []
        
        // Interleave them: 1 from Spotify, 1 from YouTube
        while !sTracks.isEmpty || !yTracks.isEmpty {
            if !sTracks.isEmpty {
                combined.append(sTracks.removeFirst())
            }
            if !yTracks.isEmpty {
                combined.append(yTracks.removeFirst())
            }
        }
        
        return (combined, yRes?.nextContinuationToken)
    }
}
