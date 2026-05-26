import Foundation
import Models
import SpotifySDK

public struct SpotifyRadioProvider: RadioEngineProvider {
    private let spotify: SpotifySDK
    
    public init(spotify: SpotifySDK) {
        self.spotify = spotify
    }
    
    public func generateNextBatch(
        seedMediaID: String,
        seedTitle: String,
        seedArtist: String,
        continuationToken: String?
    ) async throws -> (tracks: [RadioEngineTrack], nextContinuationToken: String?) {
        
        let query = "\(seedTitle) \(seedArtist)"
        
        // 1. Find the seed SpotifyTrack
        let searchResults = try await spotify.search.search(query, limit: 1)
        guard let seedTrack = searchResults.tracks?.items.first else {
            throw NSError(domain: "SpotifyRadioProvider", code: 404, userInfo: [NSLocalizedDescriptionKey: "Seed track not found on Spotify"])
        }
        
        // 2. Generate recommendations
        let recommendedTracks = try await spotify.recommendations.generateRecommendations(for: seedTrack, limit: 30)
        
        // 3. Map to RadioEngineTrack
        let tracks = recommendedTracks.map { spotifyTrack in
            RadioEngineTrack(
                mediaID: "spotify-\(spotifyTrack.id)", // Prefix to avoid ID collisions
                title: spotifyTrack.name,
                artist: spotifyTrack.artists.map(\.name).joined(separator: ", "),
                albumName: spotifyTrack.album?.name,
                artworkURL: spotifyTrack.album?.images.first?.url,
                isExplicit: spotifyTrack.isExplicit ?? false
            )
        }
        
        // Return a dummy token so the queue manager knows it can fetch more, but we just generate fresh ones next time
        return (tracks, UUID().uuidString)
    }
}
