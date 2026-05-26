import Foundation
import Models
import YouTubeSDK

public struct YouTubeRadioProvider: RadioEngineProvider {
    private let youtube: YouTube
    
    public init(youtube: YouTube) {
        self.youtube = youtube
    }
    
    public func generateNextBatch(
        seedMediaID: String,
        seedTitle: String,
        seedArtist: String,
        continuationToken: String?
    ) async throws -> (tracks: [RadioEngineTrack], nextContinuationToken: String?) {
        
        // If we have a continuation token, fetch the next page
        if let token = continuationToken {
            let page = try await youtube.music.getRadioContinuation(token: token)
            let tracks = page.items.map { song in
                RadioEngineTrack(
                    mediaID: song.videoId,
                    title: song.title,
                    artist: song.artistsDisplay,
                    albumName: song.album,
                    artworkURL: song.thumbnailURL,
                    isExplicit: song.isExplicit
                )
            }
            return (tracks, page.continuationToken)
        }
        
        // If no token, we start a fresh radio based on the seed
        let radioId = "RDAMVM\(seedMediaID)"
        do {
            let page = try await youtube.music.getRadio(videoId: seedMediaID, playlistId: radioId)
            let tracks = page.items.map { song in
                RadioEngineTrack(
                    mediaID: song.videoId,
                    title: song.title,
                    artist: song.artistsDisplay,
                    albumName: song.album,
                    artworkURL: song.thumbnailURL,
                    isExplicit: song.isExplicit
                )
            }
            return (tracks, page.continuationToken)
        } catch {
            // Fallback: If getRadio fails, attempt getRadioContinuation directly with the synthesized token
            let page = try await youtube.music.getRadioContinuation(token: radioId)
            let tracks = page.items.map { song in
                RadioEngineTrack(
                    mediaID: song.videoId,
                    title: song.title,
                    artist: song.artistsDisplay,
                    albumName: song.album,
                    artworkURL: song.thumbnailURL,
                    isExplicit: song.isExplicit
                )
            }
            return (tracks, page.continuationToken)
        }
    }
}
