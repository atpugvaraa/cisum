import Foundation
import SwiftData
import Models
import Utilities

#if canImport(SpotifySDK)
import SpotifySDK
#endif

@MainActor
@Observable
public final class CentralMediaStore {
    public struct ArtistSnapshot: Sendable {
        public let displayName: String
        public let normalizedName: String
        public let artworkURLString: String?
        public let genres: [String]
        public let spotifyArtistID: String?
        public let spotifyArtistURI: String?
        public let youtubeChannelID: String?
        public let youtubeMusicBrowseID: String?
        public let appleMusicArtistID: String?

        public init(displayName: String, normalizedName: String, artworkURLString: String?, genres: [String], spotifyArtistID: String?, spotifyArtistURI: String?, youtubeChannelID: String?, youtubeMusicBrowseID: String?, appleMusicArtistID: String?) {
            self.displayName = displayName
            self.normalizedName = normalizedName
            self.artworkURLString = artworkURLString
            self.genres = genres
            self.spotifyArtistID = spotifyArtistID
            self.spotifyArtistURI = spotifyArtistURI
            self.youtubeChannelID = youtubeChannelID
            self.youtubeMusicBrowseID = youtubeMusicBrowseID
            self.appleMusicArtistID = appleMusicArtistID
        }
    }

    public struct AlbumSnapshot: Sendable {
        public let title: String
        public let normalizedTitle: String
        public let primaryArtistName: String?
        public let primaryArtistID: String?
        public let artworkURLString: String?
        public let releaseDateString: String?
        public let totalTracks: Int?
        public let spotifyAlbumID: String?
        public let spotifyAlbumURI: String?
        public let youtubePlaylistID: String?
        public let appleMusicAlbumID: String?

        public init(title: String, normalizedTitle: String, primaryArtistName: String?, primaryArtistID: String?, artworkURLString: String?, releaseDateString: String?, totalTracks: Int?, spotifyAlbumID: String?, spotifyAlbumURI: String?, youtubePlaylistID: String?, appleMusicAlbumID: String?) {
            self.title = title
            self.normalizedTitle = normalizedTitle
            self.primaryArtistName = primaryArtistName
            self.primaryArtistID = primaryArtistID
            self.artworkURLString = artworkURLString
            self.releaseDateString = releaseDateString
            self.totalTracks = totalTracks
            self.spotifyAlbumID = spotifyAlbumID
            self.spotifyAlbumURI = spotifyAlbumURI
            self.youtubePlaylistID = youtubePlaylistID
            self.appleMusicAlbumID = appleMusicAlbumID
        }
    }

    public struct SongSnapshot: Sendable {
        public let title: String
        public let normalizedTitle: String
        public let primaryArtistName: String?
        public let primaryArtistID: String?
        public let albumTitle: String?
        public let albumID: String?
        public let durationSeconds: Double?
        public let artworkURLString: String?
        public let isExplicit: Bool
        public let providerFingerprint: String
        public let spotifyTrackID: String?
        public let spotifyTrackURI: String?
        public let spotifyPreviewURLString: String?
        public let youtubeVideoID: String?
        public let youtubeMusicVideoID: String?
        public let appleMusicSongID: String?

        public init(title: String, normalizedTitle: String, primaryArtistName: String?, primaryArtistID: String?, albumTitle: String?, albumID: String?, durationSeconds: Double?, artworkURLString: String?, isExplicit: Bool, providerFingerprint: String, spotifyTrackID: String?, spotifyTrackURI: String?, spotifyPreviewURLString: String?, youtubeVideoID: String?, youtubeMusicVideoID: String?, appleMusicSongID: String?) {
            self.title = title
            self.normalizedTitle = normalizedTitle
            self.primaryArtistName = primaryArtistName
            self.primaryArtistID = primaryArtistID
            self.albumTitle = albumTitle
            self.albumID = albumID
            self.durationSeconds = durationSeconds
            self.artworkURLString = artworkURLString
            self.isExplicit = isExplicit
            self.providerFingerprint = providerFingerprint
            self.spotifyTrackID = spotifyTrackID
            self.spotifyTrackURI = spotifyTrackURI
            self.spotifyPreviewURLString = spotifyPreviewURLString
            self.youtubeVideoID = youtubeVideoID
            self.youtubeMusicVideoID = youtubeMusicVideoID
            self.appleMusicSongID = appleMusicSongID
        }
    }

    public struct PlaylistSnapshot: Sendable {
        public let name: String
        public let normalizedName: String
        public let subtitle: String?
        public let descriptionText: String?
        public let ownerName: String?
        public let artworkURLString: String?
        public let spotifyPlaylistID: String?
        public let spotifyPlaylistURI: String?
        public let youtubePlaylistID: String?
        public let appleMusicPlaylistID: String?
        public let trackIDs: [String]

        public init(name: String, normalizedName: String, subtitle: String?, descriptionText: String?, ownerName: String?, artworkURLString: String?, spotifyPlaylistID: String?, spotifyPlaylistURI: String?, youtubePlaylistID: String?, appleMusicPlaylistID: String?, trackIDs: [String]) {
            self.name = name
            self.normalizedName = normalizedName
            self.subtitle = subtitle
            self.descriptionText = descriptionText
            self.ownerName = ownerName
            self.artworkURLString = artworkURLString
            self.spotifyPlaylistID = spotifyPlaylistID
            self.spotifyPlaylistURI = spotifyPlaylistURI
            self.youtubePlaylistID = youtubePlaylistID
            self.appleMusicPlaylistID = appleMusicPlaylistID
            self.trackIDs = trackIDs
        }
    }

    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    public func upsertArtist(_ snapshot: ArtistSnapshot) -> Artist {
        let entry = existingArtist(for: snapshot) ?? Artist(
            displayName: snapshot.displayName,
            normalizedName: snapshot.normalizedName
        )

        if entry.modelContext == nil {
            context.insert(entry)
        }

        entry.displayName = snapshot.displayName
        entry.normalizedName = snapshot.normalizedName
        entry.artworkURLString = snapshot.artworkURLString
        entry.genresJSONString = encodeStringArray(snapshot.genres)
        entry.spotifyArtistID = snapshot.spotifyArtistID
        entry.spotifyArtistURI = snapshot.spotifyArtistURI
        entry.youtubeChannelID = snapshot.youtubeChannelID
        entry.youtubeMusicBrowseID = snapshot.youtubeMusicBrowseID
        entry.appleMusicArtistID = snapshot.appleMusicArtistID
        entry.updatedAt = .now

        saveContext()
        return entry
    }

    @discardableResult
    public func upsertAlbum(_ snapshot: AlbumSnapshot) -> Album {
        let entry = existingAlbum(for: snapshot) ?? Album(
            title: snapshot.title,
            normalizedTitle: snapshot.normalizedTitle
        )

        if entry.modelContext == nil {
            context.insert(entry)
        }

        entry.title = snapshot.title
        entry.normalizedTitle = snapshot.normalizedTitle
        entry.primaryArtistName = snapshot.primaryArtistName
        entry.primaryArtistID = snapshot.primaryArtistID
        entry.artworkURLString = snapshot.artworkURLString
        entry.releaseDateString = snapshot.releaseDateString
        entry.totalTracks = snapshot.totalTracks
        entry.spotifyAlbumID = snapshot.spotifyAlbumID
        entry.spotifyAlbumURI = snapshot.spotifyAlbumURI
        entry.youtubePlaylistID = snapshot.youtubePlaylistID
        entry.appleMusicAlbumID = snapshot.appleMusicAlbumID
        entry.updatedAt = .now

        saveContext()
        return entry
    }

    @discardableResult
    public func upsertSong(_ snapshot: SongSnapshot) -> Song {
        let entry = existingSong(for: snapshot) ?? Song(
            title: snapshot.title,
            normalizedTitle: snapshot.normalizedTitle,
            providerFingerprint: snapshot.providerFingerprint
        )

        if entry.modelContext == nil {
            context.insert(entry)
        }

        entry.title = snapshot.title
        entry.normalizedTitle = snapshot.normalizedTitle
        entry.primaryArtistName = snapshot.primaryArtistName
        entry.primaryArtistID = snapshot.primaryArtistID
        entry.albumTitle = snapshot.albumTitle
        entry.albumID = snapshot.albumID
        entry.durationSeconds = snapshot.durationSeconds
        entry.artworkURLString = snapshot.artworkURLString
        entry.isExplicit = snapshot.isExplicit
        entry.providerFingerprint = snapshot.providerFingerprint
        entry.spotifyTrackID = snapshot.spotifyTrackID
        entry.spotifyTrackURI = snapshot.spotifyTrackURI
        entry.spotifyPreviewURLString = snapshot.spotifyPreviewURLString
        entry.youtubeVideoID = snapshot.youtubeVideoID
        entry.youtubeMusicVideoID = snapshot.youtubeMusicVideoID
        entry.appleMusicSongID = snapshot.appleMusicSongID
        entry.updatedAt = .now

        saveContext()
        return entry
    }

    @discardableResult
    public func upsertPlaylist(_ snapshot: PlaylistSnapshot) -> Playlist {
        let entry = existingPlaylist(for: snapshot) ?? Playlist(
            title: snapshot.name,
            normalizedTitle: snapshot.normalizedName
        )

        if entry.modelContext == nil {
            context.insert(entry)
        }

        entry.title = snapshot.name
        entry.normalizedTitle = snapshot.normalizedName
        entry.subtitle = snapshot.subtitle
        entry.descriptionText = snapshot.descriptionText
        entry.ownerName = snapshot.ownerName
        entry.artworkURLString = snapshot.artworkURLString
        
        if let spotifyID = snapshot.spotifyPlaylistID {
            entry.sourceProvider = .spotify
            entry.sourcePlaylistID = spotifyID
            entry.sourceURLString = snapshot.spotifyPlaylistURI
        } else if let youtubeID = snapshot.youtubePlaylistID {
            entry.sourceProvider = .youtube
            entry.sourcePlaylistID = youtubeID
        } else if let appleID = snapshot.appleMusicPlaylistID {
            entry.sourceProvider = .appleMusic
            entry.sourcePlaylistID = appleID
        }

        entry.itemCount = snapshot.trackIDs.count
        entry.songIDs = encodeStringArray(snapshot.trackIDs)?.data(using: .utf8)
        entry.updatedAt = .now

        saveContext()
        return entry
    }

    public func songBySpotifyTrackID(_ spotifyTrackID: String) -> Song? {
        let trimmedID = spotifyTrackID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedID.isEmpty else { return nil }

        var descriptor = FetchDescriptor<Song>(
            predicate: #Predicate { $0.spotifyTrackID == trimmedID }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    public func cacheSpotifyPlaybackTarget(
        spotifyTrackID: String,
        mediaID: String,
        provider: MediaProvider
    ) {
        guard let song = songBySpotifyTrackID(spotifyTrackID) else {
            return
        }

        song.cachedFallbackMediaID = mediaID
        song.preferredFallbackProvider = provider
        song.lastResolvedAt = .now
        saveContext()
    }

    public func playlistBySpotifyID(_ spotifyPlaylistID: String) -> Playlist? {
        let trimmedID = spotifyPlaylistID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedID.isEmpty else { return nil }

        let spotifyRaw = PlaylistSource.spotify.rawValue
        var descriptor = FetchDescriptor<Playlist>(
            predicate: #Predicate { $0.sourceProviderRawValue == spotifyRaw && $0.sourcePlaylistID == trimmedID }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    public func decodeTrackCanonicalIDs(for playlist: Playlist) -> [String] {
        guard let data = playlist.songIDs else {
            return []
        }

        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }
}

#if canImport(SpotifySDK)
extension CentralMediaStore {
    @discardableResult
    public func upsertSpotifyArtist(_ artist: SpotifyArtist) -> Artist {
        let snapshot = ArtistSnapshot(
            displayName: artist.name,
            normalizedName: normalizedRankingText(artist.name),
            artworkURLString: artist.images.first?.url.absoluteString,
            genres: artist.genres,
            spotifyArtistID: artist.id,
            spotifyArtistURI: artist.uri,
            youtubeChannelID: nil,
            youtubeMusicBrowseID: nil,
            appleMusicArtistID: nil
        )

        return upsertArtist(snapshot)
    }

    @discardableResult
    public func upsertSpotifyAlbum(_ album: SpotifyAlbum) -> Album {
        let primaryArtist = album.artists.first
        let primaryArtistEntry = primaryArtist.map { upsertSpotifyArtist($0) }

        let snapshot = AlbumSnapshot(
            title: album.name,
            normalizedTitle: normalizedRankingText(album.name),
            primaryArtistName: primaryArtist?.name,
            primaryArtistID: primaryArtistEntry?.artistID,
            artworkURLString: album.images.first?.url.absoluteString,
            releaseDateString: album.releaseDate,
            totalTracks: album.totalTracks,
            spotifyAlbumID: album.id,
            spotifyAlbumURI: album.uri,
            youtubePlaylistID: nil,
            appleMusicAlbumID: nil
        )

        return upsertAlbum(snapshot)
    }

    @discardableResult
    public func upsertSpotifyTrack(_ track: SpotifyTrack) -> Song {
        let primaryArtist = track.artists.first
        let primaryArtistEntry = primaryArtist.map { upsertSpotifyArtist($0) }
        let albumEntry = track.album.map { upsertSpotifyAlbum($0) }

        let normalizedTitle = normalizedRankingText(track.name)
        let normalizedArtist = normalizedRankingText(primaryArtist?.name ?? "")
        let fingerprint = makeProviderFingerprint(title: normalizedTitle, artist: normalizedArtist)

        let snapshot = SongSnapshot(
            title: track.name,
            normalizedTitle: normalizedTitle,
            primaryArtistName: primaryArtist?.name,
            primaryArtistID: primaryArtistEntry?.artistID,
            albumTitle: track.album?.name,
            albumID: albumEntry?.albumID,
            durationSeconds: TimeInterval(track.durationMS) / 1000,
            artworkURLString: track.album?.images.first?.url.absoluteString,
            isExplicit: track.isExplicit ?? false,
            providerFingerprint: fingerprint,
            spotifyTrackID: track.id,
            spotifyTrackURI: track.uri,
            spotifyPreviewURLString: track.previewURL?.absoluteString,
            youtubeVideoID: nil,
            youtubeMusicVideoID: nil,
            appleMusicSongID: nil
        )

        return upsertSong(snapshot)
    }

    @discardableResult
    public func upsertSpotifyPlaylist(_ playlist: SpotifyPlaylist) -> Playlist {
        let snapshot = PlaylistSnapshot(
            name: playlist.name,
            normalizedName: normalizedRankingText(playlist.name),
            subtitle: playlist.description,
            descriptionText: playlist.description,
            ownerName: playlist.owner?.displayName,
            artworkURLString: playlist.images.first?.url.absoluteString,
            spotifyPlaylistID: playlist.id,
            spotifyPlaylistURI: playlist.uri,
            youtubePlaylistID: nil,
            appleMusicPlaylistID: nil,
            trackIDs: playlist.tracks?.items.map { upsertSpotifyTrack($0).songID } ?? []
        )

        return upsertPlaylist(snapshot)
    }

    @discardableResult
    public func upsertSpotifyTracks(_ tracks: [SpotifyTrack]) -> [Song] {
        tracks.map { upsertSpotifyTrack($0) }
    }

    @discardableResult
    public func upsertSpotifyArtists(_ artists: [SpotifyArtist]) -> [Artist] {
        artists.map { upsertSpotifyArtist($0) }
    }

    @discardableResult
    public func upsertSpotifyPlaylists(_ playlists: [SpotifyPlaylist]) -> [Playlist] {
        playlists.map { upsertSpotifyPlaylist($0) }
    }
}
#endif

private extension CentralMediaStore {
    func existingArtist(for snapshot: ArtistSnapshot) -> Artist? {
        if let spotifyArtistID = snapshot.spotifyArtistID,
           let match = fetchFirstArtist(predicate: #Predicate { $0.spotifyArtistID == spotifyArtistID }) {
            return match
        }

        if let youtubeChannelID = snapshot.youtubeChannelID,
           let match = fetchFirstArtist(predicate: #Predicate { $0.youtubeChannelID == youtubeChannelID }) {
            return match
        }

        if let youtubeMusicBrowseID = snapshot.youtubeMusicBrowseID,
           let match = fetchFirstArtist(predicate: #Predicate { $0.youtubeMusicBrowseID == youtubeMusicBrowseID }) {
            return match
        }


        if let appleMusicArtistID = snapshot.appleMusicArtistID,
           let match = fetchFirstArtist(predicate: #Predicate { $0.appleMusicArtistID == appleMusicArtistID }) {
            return match
        }

        let normalizedName = snapshot.normalizedName
        return fetchFirstArtist(predicate: #Predicate { $0.normalizedName == normalizedName })
    }

    func existingAlbum(for snapshot: AlbumSnapshot) -> Album? {
        if let spotifyAlbumID = snapshot.spotifyAlbumID,
           let match = fetchFirstAlbum(predicate: #Predicate { $0.spotifyAlbumID == spotifyAlbumID }) {
            return match
        }

        if let youtubePlaylistID = snapshot.youtubePlaylistID,
           let match = fetchFirstAlbum(predicate: #Predicate { $0.youtubePlaylistID == youtubePlaylistID }) {
            return match
        }


        if let appleMusicAlbumID = snapshot.appleMusicAlbumID,
           let match = fetchFirstAlbum(predicate: #Predicate { $0.appleMusicAlbumID == appleMusicAlbumID }) {
            return match
        }

        let normalizedTitle = snapshot.normalizedTitle
        return fetchFirstAlbum(predicate: #Predicate { $0.normalizedTitle == normalizedTitle })
    }

    func existingSong(for snapshot: SongSnapshot) -> Song? {
        if let spotifyTrackID = snapshot.spotifyTrackID,
           let match = fetchFirstSong(predicate: #Predicate { $0.spotifyTrackID == spotifyTrackID }) {
            return match
        }

        if let youtubeVideoID = snapshot.youtubeVideoID,
           let match = fetchFirstSong(predicate: #Predicate { $0.youtubeVideoID == youtubeVideoID }) {
            return match
        }

        if let youtubeMusicVideoID = snapshot.youtubeMusicVideoID,
           let match = fetchFirstSong(predicate: #Predicate { $0.youtubeMusicVideoID == youtubeMusicVideoID }) {
            return match
        }


        if let appleMusicSongID = snapshot.appleMusicSongID,
           let match = fetchFirstSong(predicate: #Predicate { $0.appleMusicSongID == appleMusicSongID }) {
            return match
        }

        let providerFingerprint = snapshot.providerFingerprint
        return fetchFirstSong(predicate: #Predicate { $0.providerFingerprint == providerFingerprint })
    }

    func existingPlaylist(for snapshot: PlaylistSnapshot) -> Playlist? {
        if let spotifyPlaylistID = snapshot.spotifyPlaylistID {
            let spotifyRaw = PlaylistSource.spotify.rawValue
            if let match = fetchFirstPlaylist(predicate: #Predicate { $0.sourceProviderRawValue == spotifyRaw && $0.sourcePlaylistID == spotifyPlaylistID }) {
                return match
            }
        }

        if let youtubePlaylistID = snapshot.youtubePlaylistID {
            let youtubeRaw = PlaylistSource.youtube.rawValue
            if let match = fetchFirstPlaylist(predicate: #Predicate { $0.sourceProviderRawValue == youtubeRaw && $0.sourcePlaylistID == youtubePlaylistID }) {
                return match
            }
        }

        if let appleMusicPlaylistID = snapshot.appleMusicPlaylistID {
            let appleRaw = PlaylistSource.appleMusic.rawValue
            if let match = fetchFirstPlaylist(predicate: #Predicate { $0.sourceProviderRawValue == appleRaw && $0.sourcePlaylistID == appleMusicPlaylistID }) {
                return match
            }
        }

        let normalizedTitle = snapshot.normalizedName
        return fetchFirstPlaylist(predicate: #Predicate { $0.normalizedTitle == normalizedTitle })
    }

    func fetchFirstArtist(predicate: Predicate<Artist>) -> Artist? {
        var descriptor = FetchDescriptor<Artist>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    func fetchFirstAlbum(predicate: Predicate<Album>) -> Album? {
        var descriptor = FetchDescriptor<Album>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    func fetchFirstSong(predicate: Predicate<Song>) -> Song? {
        var descriptor = FetchDescriptor<Song>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    func fetchFirstPlaylist(predicate: Predicate<Playlist>) -> Playlist? {
        var descriptor = FetchDescriptor<Playlist>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    func saveContext() {
        try? context.save()
    }

    func encodeStringArray(_ values: [String]) -> String? {
        let cleanedValues = values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !cleanedValues.isEmpty else {
            return nil
        }

        guard let data = try? JSONEncoder().encode(cleanedValues) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func makeProviderFingerprint(title: String, artist: String) -> String {
        "\(title)|\(artist)"
    }
}
