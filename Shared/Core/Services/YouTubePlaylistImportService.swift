import Foundation
import YouTubeSDK

@MainActor
final class YouTubePlaylistImportService {
    enum PlaylistImportError: LocalizedError {
        case emptyQuery
        case invalidPlaylistLink
        case playlistNotFound
        case playlistHasNoTracks

        var errorDescription: String? {
            switch self {
            case .emptyQuery:
                return "Enter a playlist name to search."
            case .invalidPlaylistLink:
                return "Enter a valid YouTube playlist link or playlist ID."
            case .playlistNotFound:
                return "Unable to find that playlist on YouTube."
            case .playlistHasNoTracks:
                return "The playlist was found but has no importable tracks."
            }
        }
    }

    private struct PlaylistLookupInfo {
        let playlistID: String
        let title: String
        let author: String?
        let thumbnailURLString: String?
    }

    private struct ParsedPlaylistLink {
        let playlistID: String
        let isMusicLink: Bool
        let canonicalURLString: String
    }

    private struct ImportedTrackPayload {
        let sourceTrackID: String
        let title: String
        let artistName: String?
        let albumName: String?
        let durationSeconds: Double?
        let artworkURLString: String?
    }

    private let youtube: YouTube
    private let playlistStore: PlaylistLibraryStore

    init(youtube: YouTube, playlistStore: PlaylistLibraryStore) {
        self.youtube = youtube
        self.playlistStore = playlistStore
    }

    func searchPlaylists(query: String, limit: Int = 30) async throws -> [YouTubePlaylist] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            throw PlaylistImportError.emptyQuery
        }

        let continuation = try await youtube.main.search(trimmedQuery)
        let playlists = continuation.items.compactMap { item -> YouTubePlaylist? in
            guard case .playlist(let playlist) = item else { return nil }
            return playlist
        }

        var seen = Set<String>()
        var deduped: [YouTubePlaylist] = []
        for playlist in playlists {
            guard seen.insert(playlist.id).inserted else { continue }
            deduped.append(playlist)
            if deduped.count >= max(limit, 1) {
                break
            }
        }

        return deduped
    }

    @discardableResult
    func importPlaylist(from playlist: YouTubePlaylist) async throws -> Playlist {
        let info = PlaylistLookupInfo(
            playlistID: playlist.id,
            title: normalizedMusicDisplayTitle(playlist.title, artist: playlist.author),
            author: normalizedMusicDisplayArtist(playlist.author ?? "", title: playlist.title),
            thumbnailURLString: playlist.thumbnailURL?.absoluteString
        )

        return try await importPlaylist(
            playlistID: playlist.id,
            preferredProvider: .youtube,
            sourceURLString: "https://www.youtube.com/playlist?list=\(playlist.id)",
            lookupInfo: info
        )
    }

    @discardableResult
    func importPlaylist(fromLink rawLink: String) async throws -> Playlist {
        let parsedLink = try parsePlaylistLink(rawLink)
        let lookupInfo = await lookupPlaylistInfo(for: parsedLink.playlistID)

        return try await importPlaylist(
            playlistID: parsedLink.playlistID,
            preferredProvider: parsedLink.isMusicLink ? .youtubeMusic : .youtube,
            sourceURLString: parsedLink.canonicalURLString,
            lookupInfo: lookupInfo
        )
    }
}

private extension YouTubePlaylistImportService {
    @discardableResult
    private func importPlaylist(
        playlistID: String,
        preferredProvider: PlaylistSourceProvider,
        sourceURLString: String,
        lookupInfo: PlaylistLookupInfo?
    ) async throws -> Playlist {
        let importResult = try await fetchTracks(
            playlistID: playlistID,
            preferredProvider: preferredProvider
        )
        let payloads = importResult.tracks

        guard !payloads.isEmpty else {
            throw PlaylistImportError.playlistHasNoTracks
        }

        let resolvedProvider = importResult.provider
        let existingPlaylist = playlistStore.playlist(
            sourceProvider: resolvedProvider,
            sourcePlaylistID: playlistID
        )

        let localPlaylistID = existingPlaylist?.playlistID ?? UUID().uuidString
        let title = lookupInfo?.title.isEmpty == false
            ? lookupInfo?.title
            : "Imported Playlist"

        let subtitle = lookupInfo?.author?.isEmpty == false ? lookupInfo?.author : nil
        let checksum = makeSourceChecksum(from: payloads)

        let playlistSnapshot = PlaylistLibraryStore.PlaylistSnapshot(
            playlistID: localPlaylistID,
            title: title ?? "Imported Playlist",
            subtitle: subtitle,
            descriptionText: nil,
            artworkURLString: lookupInfo?.thumbnailURLString,
            sourceProvider: resolvedProvider,
            sourcePlaylistID: playlistID,
            sourceURLString: sourceURLString,
            sourceOwnerName: subtitle,
            sourceChecksum: checksum,
            itemCount: payloads.count,
            importedAt: existingPlaylist?.importedAt ?? .now,
            updatedAt: .now,
            lastPlayedAt: existingPlaylist?.lastPlayedAt
        )

        let itemSnapshots = payloads.enumerated().map { index, track in
            PlaylistLibraryStore.PlaylistItemSnapshot(
                sortIndex: index,
                sourceTrackID: track.sourceTrackID,
                sourceTrackFingerprint: makeTrackFingerprint(track),
                title: track.title,
                artistName: track.artistName,
                albumName: track.albumName,
                durationSeconds: track.durationSeconds,
                artworkURLString: track.artworkURLString,
                resolvedMediaID: track.sourceTrackID,
                resolutionConfidence: 1,
                importStatus: .matched,
                importErrorCode: nil,
                importErrorMessage: nil
            )
        }

        let playlist = playlistStore.upsertPlaylist(playlistSnapshot)
        playlistStore.replaceItems(for: localPlaylistID, with: itemSnapshots)
        return playlist
    }

    private func fetchTracks(
        playlistID: String,
        preferredProvider: PlaylistSourceProvider
    ) async throws -> (provider: PlaylistSourceProvider, tracks: [ImportedTrackPayload]) {
        let preferMusic = preferredProvider == .youtubeMusic

        if preferMusic {
            if let musicTracks = try await fetchTracksFromMusicPlaylist(playlistID: playlistID), !musicTracks.isEmpty {
                return (.youtubeMusic, musicTracks)
            }
            if let mainTracks = try await fetchTracksFromMainPlaylist(playlistID: playlistID), !mainTracks.isEmpty {
                return (.youtube, mainTracks)
            }
        } else {
            if let mainTracks = try await fetchTracksFromMainPlaylist(playlistID: playlistID), !mainTracks.isEmpty {
                return (.youtube, mainTracks)
            }
            if let musicTracks = try await fetchTracksFromMusicPlaylist(playlistID: playlistID), !musicTracks.isEmpty {
                return (.youtubeMusic, musicTracks)
            }
        }

        throw PlaylistImportError.playlistNotFound
    }

    private func fetchTracksFromMainPlaylist(playlistID: String, maxPages: Int = 12) async throws -> [ImportedTrackPayload]? {
        let firstPage: YouTubeContinuation<YouTubeVideo>
        do {
            firstPage = try await youtube.main.getPlaylist(id: playlistID)
        } catch {
            return nil
        }

        var payloads = firstPage.items.compactMap(makePayload(from:))
        var seenTrackIDs = Set(payloads.map(\.sourceTrackID))
        var token = firstPage.continuationToken
        var pagesLoaded = 0

        while let continuationToken = token,
              !continuationToken.isEmpty,
              pagesLoaded < maxPages {
            pagesLoaded += 1
            let page = try await youtube.main.fetchContinuation(token: continuationToken)

            for item in page.items {
                switch item {
                case .video(let video):
                    if let payload = makePayload(from: video),
                       seenTrackIDs.insert(payload.sourceTrackID).inserted {
                        payloads.append(payload)
                    }
                case .song(let song):
                    if let payload = makePayload(from: song),
                       seenTrackIDs.insert(payload.sourceTrackID).inserted {
                        payloads.append(payload)
                    }
                default:
                    continue
                }
            }

            token = page.continuationToken
        }

        return payloads
    }

    private func fetchTracksFromMusicPlaylist(playlistID: String) async throws -> [ImportedTrackPayload]? {
        let songs: [YouTubeMusicSong]
        do {
            songs = try await youtube.music.getPlaylist(browseId: playlistID)
        } catch {
            return nil
        }

        let payloads = songs.compactMap(makePayload(from:))
        return payloads
    }

    private func parsePlaylistLink(_ rawValue: String) throws -> ParsedPlaylistLink {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw PlaylistImportError.invalidPlaylistLink
        }

        if isLikelyPlaylistID(trimmed) {
            return ParsedPlaylistLink(
                playlistID: trimmed,
                isMusicLink: false,
                canonicalURLString: "https://www.youtube.com/playlist?list=\(trimmed)"
            )
        }

        let normalizedURLString: String
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            normalizedURLString = trimmed
        } else {
            normalizedURLString = "https://\(trimmed)"
        }

        guard let components = URLComponents(string: normalizedURLString),
              let queryItems = components.queryItems,
              let listID = queryItems.first(where: { $0.name == "list" })?.value,
              !listID.isEmpty else {
            throw PlaylistImportError.invalidPlaylistLink
        }

        let isMusicLink = (components.host ?? "").contains("music.youtube.com")
        return ParsedPlaylistLink(
            playlistID: listID,
            isMusicLink: isMusicLink,
            canonicalURLString: "https://www.youtube.com/playlist?list=\(listID)"
        )
    }

    private func lookupPlaylistInfo(for playlistID: String) async -> PlaylistLookupInfo? {
        let queries = [
            "https://www.youtube.com/playlist?list=\(playlistID)",
            playlistID,
            "youtube playlist \(playlistID)"
        ]

        for query in queries {
            if let continuation = try? await youtube.main.search(query) {
                let playlistMatches = continuation.items.compactMap { item -> YouTubePlaylist? in
                    guard case .playlist(let playlist) = item else { return nil }
                    return playlist
                }

                if let exact = playlistMatches.first(where: { $0.id == playlistID }) ?? playlistMatches.first {
                    return PlaylistLookupInfo(
                        playlistID: exact.id,
                        title: normalizedMusicDisplayTitle(exact.title, artist: exact.author),
                        author: normalizedMusicDisplayArtist(exact.author ?? "", title: exact.title),
                        thumbnailURLString: exact.thumbnailURL?.absoluteString
                    )
                }
            }
        }

        return nil
    }

    private func makePayload(from video: YouTubeVideo) -> ImportedTrackPayload? {
        let id = video.id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { return nil }

        return ImportedTrackPayload(
            sourceTrackID: id,
            title: normalizedMusicDisplayTitle(video.title, artist: video.author),
            artistName: normalizedMusicDisplayArtist(video.author, title: video.title),
            albumName: nil,
            durationSeconds: parseDuration(from: video.lengthInSeconds),
            artworkURLString: video.thumbnailURL
        )
    }

    private func makePayload(from song: YouTubeMusicSong) -> ImportedTrackPayload? {
        let id = song.videoId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { return nil }

        return ImportedTrackPayload(
            sourceTrackID: id,
            title: normalizedMusicDisplayTitle(song.title, artist: song.artistsDisplay),
            artistName: normalizedMusicDisplayArtist(song.artistsDisplay, title: song.title),
            albumName: song.album,
            durationSeconds: song.duration,
            artworkURLString: song.thumbnailURL?.absoluteString
        )
    }

    private func parseDuration(from value: String) -> Double? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let seconds = Double(trimmed), seconds > 0 {
            return seconds
        }

        let parts = trimmed.split(separator: ":").compactMap { Double($0) }
        switch parts.count {
        case 2:
            return (parts[0] * 60) + parts[1]
        case 3:
            return (parts[0] * 3600) + (parts[1] * 60) + parts[2]
        default:
            return nil
        }
    }

    private func makeTrackFingerprint(_ track: ImportedTrackPayload) -> String {
        let normalizedTitle = normalizedMusicDisplayTitle(track.title, artist: track.artistName).lowercased()
        let normalizedArtist = normalizedMusicDisplayArtist(track.artistName ?? "", title: track.title).lowercased()
        return "\(track.sourceTrackID.lowercased())|\(normalizedArtist)|\(normalizedTitle)"
    }

    private func makeSourceChecksum(from tracks: [ImportedTrackPayload]) -> String {
        let joinedIDs = tracks.map(\.sourceTrackID).joined(separator: ",")
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in joinedIDs.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return "\(tracks.count):\(String(hash, radix: 16))"
    }

    private func isLikelyPlaylistID(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 10 else { return false }
        let validPattern = "^[A-Za-z0-9_-]+$"
        return trimmed.range(of: validPattern, options: .regularExpression) != nil
    }
}