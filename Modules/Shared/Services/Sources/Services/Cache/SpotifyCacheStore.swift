import Foundation
import SwiftData
import SpotifySDK
import Models

@MainActor
public final class SpotifyCacheStore: SpotifyCacheDelegate {
    
    private let context: ModelContext
    
    public init(context: ModelContext) {
        self.context = context
    }
    
    // MARK: - Profile
    
    public func getCachedProfile() async throws -> SpotifyAccountProfile? {
        try fetch(key: "profile", type: SpotifyAccountProfile.self)
    }
    
    public func saveProfile(_ profile: SpotifyAccountProfile) async throws {
        try save(key: "profile", value: profile)
    }
    
    // MARK: - Top Tracks
    
    public func getCachedTopTracks(timeRange: String) async throws -> [SpotifyTrack]? {
        try fetch(key: "top_tracks_\(timeRange)", type: [SpotifyTrack].self)
    }
    
    public func saveTopTracks(_ tracks: [SpotifyTrack], timeRange: String) async throws {
        try save(key: "top_tracks_\(timeRange)", value: tracks)
    }
    
    // MARK: - Top Artists
    
    public func getCachedTopArtists(timeRange: String) async throws -> [SpotifyArtist]? {
        try fetch(key: "top_artists_\(timeRange)", type: [SpotifyArtist].self)
    }
    
    public func saveTopArtists(_ artists: [SpotifyArtist], timeRange: String) async throws {
        try save(key: "top_artists_\(timeRange)", value: artists)
    }
    
    // MARK: - Generic Library
    
    public func getCachedLibraryPlaylists() async throws -> [SpotifyLibraryPlaylistSummary]? {
        try fetch(key: "library_playlists", type: [SpotifyLibraryPlaylistSummary].self)
    }
    
    public func saveLibraryPlaylists(_ playlists: [SpotifyLibraryPlaylistSummary]) async throws {
        try save(key: "library_playlists", value: playlists)
    }
    
    public func clearAll() async throws {
        try context.delete(model: SpotifyCacheEntry.self)
        try context.save()
    }
    
    // MARK: - Private Helpers
    
    private func fetch<T: Decodable>(key: String, type: T.Type) throws -> T? {
        let fetchDescriptor = FetchDescriptor<SpotifyCacheEntry>(predicate: #Predicate { $0.key == key })
        guard let entry = try context.fetch(fetchDescriptor).first else { return nil }
        return try JSONDecoder().decode(T.self, from: entry.payload)
    }
    
    private func save<T: Encodable>(key: String, value: T) throws {
        let payload = try JSONEncoder().encode(value)
        let fetchDescriptor = FetchDescriptor<SpotifyCacheEntry>(predicate: #Predicate { $0.key == key })
        if let entry = try context.fetch(fetchDescriptor).first {
            entry.payload = payload
            entry.updatedAt = Date()
        } else {
            let entry = SpotifyCacheEntry(key: key, payload: payload)
            context.insert(entry)
        }
        try context.save()
    }
}
