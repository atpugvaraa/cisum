import Foundation
import ProviderSDK
import Models

/// Defines a strategy for resolving a playback stream for a given external track.
public protocol StreamResolutionProvider: Sendable {
    /// Attempts to resolve a playable stream URL and its associated candidates.
    /// - Parameters:
    ///   - mediaID: The external media identifier (e.g., YouTube Video ID, Spotify Track ID).
    ///   - title: The title of the track.
    ///   - artist: The primary artist of the track.
    ///   - forceDecipher: If true, bypasses any local caching and forces a fresh network resolution.
    /// - Returns: An array of playback candidates sorted by preference (highest quality first).
    /// - Throws: An error if the provider cannot resolve the stream.
    func resolveStream(
        mediaID: String,
        title: String,
        artist: String,
        representations: [TrackRepresentation]?,
        forceDecipher: Bool
    ) async throws -> [PlaybackCandidate]

    /// Optionally returns a cached fast-start URL if available.
    func cachedURL(for mediaID: String) async -> URL?
}
