import Foundation
import SwiftData
import Models
import Utilities

#if canImport(SpotifySDK)
import SpotifySDK

public struct SpotifyPersonalPlaylistSummary: Identifiable, Sendable, Hashable {
    public let id: String
    public let uri: String
    public let name: String
    public let ownerName: String?
    public let artworkURL: URL?
    public let totalTracks: Int?

    public init(id: String, uri: String, name: String, ownerName: String?, artworkURL: URL?, totalTracks: Int?) {
        self.id = id
        self.uri = uri
        self.name = name
        self.ownerName = ownerName
        self.artworkURL = artworkURL
        self.totalTracks = totalTracks
    }
}

// MARK: - Spotify Playlist URL Parser

public enum SpotifyPlaylistURLParser {
    /// Extracts a Spotify playlist ID from any supported format:
    /// - https://open.spotify.com/playlist/{id}
    /// - spotify:playlist:{id}
    /// - Raw playlist ID (22-char base62)
    public static func extractPlaylistID(from input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        // spotify:playlist:{id}
        if trimmed.hasPrefix("spotify:playlist:") {
            let id = String(trimmed.dropFirst("spotify:playlist:".count))
                .components(separatedBy: "?").first ?? ""
            return id.isEmpty ? nil : id
        }

        // https://open.spotify.com/playlist/{id}?...
        if let url = URL(string: trimmed),
           let host = url.host,
           host.contains("spotify.com") {
            let pathComponents = url.pathComponents
            if let idx = pathComponents.firstIndex(of: "playlist"),
               idx + 1 < pathComponents.count {
                let id = pathComponents[idx + 1]
                return id.isEmpty ? nil : id
            }
        }

        // Raw ID: 20–28 base62 characters
        let base62 = CharacterSet.alphanumerics
        if trimmed.count >= 20 && trimmed.count <= 28,
           trimmed.unicodeScalars.allSatisfy({ base62.contains($0) }) {
            return trimmed
        }

        return nil
    }
}

// MARK: - Spotify Playlist Import Service

@MainActor
public final class SpotifyPlaylistImportService {
    private let sdk: SpotifySDK
    private let playlistStore: PlaylistLibraryStore
    private let centralStore: CentralMediaStore?

    public init(
        sdk: SpotifySDK,
        playlistStore: PlaylistLibraryStore,
        centralStore: CentralMediaStore? = nil
    ) {
        self.sdk = sdk
        self.playlistStore = playlistStore
        self.centralStore = centralStore
    }

    public func fetchPersonalPlaylists(limit: Int = 30) async throws -> [SpotifyPersonalPlaylistSummary] {
        Utilities.Logger.log("SpotifyPlaylistImportService: Fetching personal playlists (limit: \(limit))")
        let clampedLimit = max(1, limit)
        let summaries = try await sdk.account.playlists(limit: clampedLimit)
        Utilities.Logger.log("SpotifyPlaylistImportService: SDK returned \(summaries.count) playlists.")
        guard !summaries.isEmpty else {
            return []
        }

        return summaries.map { summary in
            SpotifyPersonalPlaylistSummary(
                id: SpotifyPlaylistURLParser.extractPlaylistID(from: summary.uri) ?? summary.uri,
                uri: summary.uri,
                name: summary.name,
                ownerName: summary.ownerDisplayName ?? summary.ownerUsername,
                artworkURL: summary.artworkURL,
                totalTracks: summary.trackCount
            )
        }
    }

    public func importPlaylists(ids: [String]) async throws -> [Playlist] {
        let uniqueIDs = Array(Set(ids))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        Utilities.Logger.log("SpotifyPlaylistImportService: Importing \(uniqueIDs.count) playlists: \(uniqueIDs)")

        guard !uniqueIDs.isEmpty else {
            throw SpotifyImportError.noImportablePlaylists
        }

        var importedPlaylists: [Playlist] = []
        importedPlaylists.reserveCapacity(uniqueIDs.count)

        for playlistID in uniqueIDs {
            do {
                let playlist = try await importPlaylist(id: playlistID)
                importedPlaylists.append(playlist)
            } catch {
                Utilities.Logger.log("SpotifyPlaylistImportService: Failed to import playlist \(playlistID): \(error.localizedDescription)")
            }
        }

        guard !importedPlaylists.isEmpty else {
            throw SpotifyImportError.noImportablePlaylists
        }

        return importedPlaylists
    }

    /// Import a Spotify playlist from a URL, URI, or raw ID string.
    public func importPlaylist(fromLink link: String) async throws -> Playlist {
        guard let playlistID = SpotifyPlaylistURLParser.extractPlaylistID(from: link) else {
            throw SpotifyImportError.invalidURL(link)
        }
        return try await importPlaylist(id: playlistID)
    }

    /// Import a Spotify playlist by its raw ID.
    public func importPlaylist(id: String, nameOverride: String? = nil) async throws -> Playlist {
        Utilities.Logger.log("SpotifyPlaylistImportService: Fetching details for playlist ID: \(id)")
        let spotifyPlaylist = try await sdk.playlists.details(id: id)
        Utilities.Logger.log("SpotifyPlaylistImportService: Fetched details for \(spotifyPlaylist.name). Starting import...")
        return try await importSpotifyPlaylist(spotifyPlaylist, nameOverride: nameOverride)
    }

    public func importLikedSongs() async throws -> Playlist {
        Utilities.Logger.log("SpotifyPlaylistImportService: Starting Liked Songs import")
        let likedSongsSummary = try await fetchLikedSongsSummary()
        Utilities.Logger.log("SpotifyPlaylistImportService: Liked songs summary: \(likedSongsSummary.trackCount ?? 0) tracks. Fetching all tracks...")
        let likedSongs = try await fetchAllLikedSongs()
        Utilities.Logger.log("SpotifyPlaylistImportService: Fetched \(likedSongs.count) liked songs.")

        guard !likedSongs.isEmpty else {
            throw SpotifyImportError.emptyPlaylist(likedSongsSummary.name)
        }

        let stablePlaylistID = "spotify-liked-songs"
        let playlistSnapshot = PlaylistLibraryStore.PlaylistSnapshot(
            playlistID: stablePlaylistID,
            title: likedSongsSummary.name,
            subtitle: likedSongsSummary.ownerDisplayName ?? likedSongsSummary.ownerUsername,
            descriptionText: likedSongsSummary.description,
            artworkURLString: likedSongsSummary.artworkURL?.absoluteString,
            sourceProvider: .spotify,
            sourcePlaylistID: likedSongsSummary.uri,
            sourceURLString: likedSongsSummary.uri,
            sourceOwnerName: likedSongsSummary.ownerDisplayName ?? likedSongsSummary.ownerUsername,
            itemCount: likedSongs.count
        )

        let playlist = playlistStore.upsertPlaylist(playlistSnapshot)
        Utilities.Logger.log("SpotifyPlaylistImportService: Upserted Liked Songs playlist with ID: \(playlist.playlistID), title: \(playlist.title)")
        let itemSnapshots = makeItemSnapshots(from: likedSongs.map(\.track))
        playlistStore.replaceItems(for: stablePlaylistID, with: itemSnapshots)
        Utilities.Logger.log("SpotifyPlaylistImportService: Liked Songs import complete (\(itemSnapshots.count) items).")

        return playlist
    }

    /// Import a pre-fetched SpotifyPlaylist into the library.
    public func importSpotifyPlaylist(_ spotifyPlaylist: SpotifyPlaylist, nameOverride: String? = nil) async throws -> Playlist {
        let tracks = spotifyPlaylist.tracks?.items ?? []
        let playlistTitle = nameOverride ?? normalizedSpotifyPlaylistTitle(spotifyPlaylist)
        Utilities.Logger.log("SpotifyPlaylistImportService: Importing \(tracks.count) tracks for playlist: \(playlistTitle)")
        guard !tracks.isEmpty else {
            throw SpotifyImportError.emptyPlaylist(playlistTitle)
        }

        // Create a new library playlist instance for every import attempt.
        let stablePlaylistID = UUID().uuidString
        let ownerName = spotifyPlaylist.owner?.displayName
        // We already resolved playlistTitle above

        let playlistSnapshot = PlaylistLibraryStore.PlaylistSnapshot(
            playlistID: stablePlaylistID,
            title: playlistTitle,
            subtitle: ownerName.map { "by \($0)" },
            descriptionText: spotifyPlaylist.description,
            artworkURLString: spotifyPlaylist.images.first?.url.absoluteString,
            sourceProvider: .spotify,
            sourcePlaylistID: spotifyPlaylist.id,
            sourceURLString: spotifyPlaylist.uri.isEmpty ? nil : spotifyPlaylist.uri,
            sourceOwnerName: ownerName,
            itemCount: tracks.count
        )

        let playlist = playlistStore.upsertPlaylist(playlistSnapshot)
        Utilities.Logger.log("SpotifyPlaylistImportService: Upserted playlist '\(playlist.title)' (ID: \(playlist.playlistID), Source: \(playlist.sourcePlaylistID ?? "nil"))")
        let itemSnapshots = makeItemSnapshots(from: tracks)
        playlistStore.replaceItems(for: stablePlaylistID, with: itemSnapshots)
        Utilities.Logger.log("SpotifyPlaylistImportService: Replaced items (\(itemSnapshots.count)) for playlist \(stablePlaylistID).")

        if let centralStore {
            _ = centralStore.upsertSpotifyPlaylist(spotifyPlaylist)
            Utilities.Logger.log("SpotifyPlaylistImportService: Updated central store.")
        }

        return playlist
    }

    public func fetchLikedSongsSummary() async throws -> SpotifyLibraryPlaylistSummary {
        let page = try await sdk.account.likedSongs(limit: 1)
        return SpotifyLibraryPlaylistSummary(
            uri: "spotify:collection:tracks",
            name: "Liked Songs",
            description: nil,
            ownerUsername: nil,
            ownerDisplayName: nil,
            artworkURL: nil,
            isPublic: nil,
            timestamp: nil,
            format: nil,
            revision: nil,
            trackCount: page.totalCount ?? page.items.count
        )
    }

    private func fetchAllLikedSongs(pageSize: Int = 100) async throws -> [SpotifyLikedSongEntry] {
        var offset = 0
        var collected: [SpotifyLikedSongEntry] = []

        while true {
            let page = try await sdk.account.likedSongs(offset: offset, limit: pageSize)
            collected.append(contentsOf: page.items)

            let totalCount = page.totalCount ?? collected.count
            if collected.count >= totalCount || page.items.isEmpty {
                break
            }

            let step = max(page.pageInfo.limit ?? pageSize, page.items.count)
            offset += step
        }

        return collected
    }

    private func makeItemSnapshots(from tracks: [SpotifyTrack]) -> [PlaylistLibraryStore.PlaylistItemSnapshot] {
        let snapshots: [PlaylistLibraryStore.PlaylistItemSnapshot] = tracks.enumerated().compactMap { index, track in
            guard !track.id.isEmpty else {
                Utilities.Logger.log("SpotifyPlaylistImportService: Skipping track '\(track.name)' at index \(index) because ID is empty.")
                return nil
            }

            let artist = track.artists.first?.name ?? "Unknown Artist"
            let fingerprint = "\(track.name)|\(artist)".lowercased()
            return PlaylistLibraryStore.PlaylistItemSnapshot(
                sortIndex: index,
                sourceTrackID: track.id,
                sourceTrackFingerprint: fingerprint,
                title: track.name,
                artistName: artist,
                albumName: track.album?.name,
                durationSeconds: track.durationMS > 0 ? Double(track.durationMS) / 1000.0 : nil,
                artworkURLString: track.album?.images.first?.url.absoluteString,
                resolvedMediaID: nil,
                resolutionConfidence: nil,
                importStatus: .pending
            )
        }

        Utilities.Logger.log("SpotifyPlaylistImportService: Created \(snapshots.count) snapshots from \(tracks.count) tracks.")
        return snapshots
    }

    private func normalizedSpotifyPlaylistTitle(_ spotifyPlaylist: SpotifyPlaylist) -> String {
        let cleanedName = spotifyPlaylist.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanedName.isEmpty {
             Utilities.Logger.log("SpotifyPlaylistImportService: Using name '\(cleanedName)' for playlist \(spotifyPlaylist.id)")
             return cleanedName
        }

        Utilities.Logger.log("SpotifyPlaylistImportService: Playlist \(spotifyPlaylist.id) has empty name, falling back to ID.")
        if !spotifyPlaylist.id.isEmpty {
            return "Spotify Playlist (\(spotifyPlaylist.id.prefix(8)))"
        }

        return "Spotify Playlist"
    }
}

// MARK: - Errors

public enum SpotifyImportError: LocalizedError {
    case invalidURL(String)
    case emptyPlaylist(String)
    case sdkUnavailable
    case noImportablePlaylists

    public var errorDescription: String? {
        switch self {
        case .invalidURL(let input):
            return "\(input) is not a valid Spotify playlist link or ID."
        case .emptyPlaylist(let name):
            return "\(name) has no importable tracks."
        case .sdkUnavailable:
            return "Spotify is not connected. Sign in via Settings to import playlists."
        case .noImportablePlaylists:
            return "No importable playlists were found in your Spotify library."
        }
    }
}

#endif
