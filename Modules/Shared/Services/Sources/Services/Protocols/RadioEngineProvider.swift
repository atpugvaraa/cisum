import Foundation
import Models

public struct RadioEngineTrack: Sendable, Hashable {
    public let mediaID: String
    public let title: String
    public let artist: String
    public let albumName: String?
    public let artworkURL: URL?
    public let isExplicit: Bool
    
    public init(
        mediaID: String,
        title: String,
        artist: String,
        albumName: String?,
        artworkURL: URL?,
        isExplicit: Bool
    ) {
        self.mediaID = mediaID
        self.title = title
        self.artist = artist
        self.albumName = albumName
        self.artworkURL = artworkURL
        self.isExplicit = isExplicit
    }
}

/// Defines a strategy for generating continuous radio queues based on a seed track.
public protocol RadioEngineProvider: Sendable {
    /// Generates the next batch of tracks for the radio queue.
    /// - Parameters:
    ///   - seedMediaID: The original seed video/track ID that started the radio.
    ///   - seedTitle: The title of the seed track (useful for cross-service lookups).
    ///   - seedArtist: The artist of the seed track.
    ///   - continuationToken: An optional token to fetch the next page of results.
    /// - Returns: A tuple containing the tracks and the next continuation token (if any).
    /// - Throws: An error if the provider cannot generate the queue.
    func generateNextBatch(
        seedMediaID: String,
        seedTitle: String,
        seedArtist: String,
        continuationToken: String?
    ) async throws -> (tracks: [RadioEngineTrack], nextContinuationToken: String?)
}
