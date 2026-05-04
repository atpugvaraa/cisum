import Foundation
import Services
import AVFoundation
import YouTubeSDK

extension PlayerViewModel {
    struct CachedRadioTrack: Identifiable, Sendable {
        var id: String { videoID }
        let videoID: String
        let title: String
        let artist: String
        let albumName: String?
        let thumbnailURL: URL?
        let isExplicit: Bool

        var fingerprint: String {
            "\(title.lowercased())|\(artist.lowercased())"
        }

        init(
            videoID: String,
            title: String,
            artist: String,
            albumName: String?,
            thumbnailURL: URL?,
            isExplicit: Bool
        ) {
            self.videoID = videoID
            self.title = title
            self.artist = artist
            self.albumName = albumName
            self.thumbnailURL = thumbnailURL
            self.isExplicit = isExplicit
        }

        init(song: YouTubeMusicSong) {
            self.videoID = song.videoId
            self.title = song.title
            self.artist = song.artistsDisplay
            self.albumName = song.album
            self.thumbnailURL = song.thumbnailURL
            self.isExplicit = song.isExplicit
        }

        init?(cached: RadioSessionStore.CachedTrack) {
            let normalizedVideoID = cached.videoID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedVideoID.isEmpty else { return nil }

            self.videoID = normalizedVideoID
            self.title = cached.title
            self.artist = cached.artist
            self.albumName = cached.albumName
            self.thumbnailURL = cached.thumbnailURLString.flatMap { URL(string: $0) }
            self.isExplicit = cached.isExplicit
        }

        var persisted: RadioSessionStore.CachedTrack {
            RadioSessionStore.CachedTrack(
                videoID: videoID,
                title: title,
                artist: artist,
                albumName: albumName,
                thumbnailURLString: thumbnailURL?.absoluteString,
                isExplicit: isExplicit
            )
        }
    }

    enum PlaybackQueueEntry {
        case song(YouTubeMusicSong)
        case video(YouTubeVideo)
        case cachedRadio(CachedRadioTrack)
        case external(ExternalQueueTrack)

        var mediaID: String {
            switch self {
            case .song(let song):
                song.videoId
            case .video(let video):
                video.id
            case .cachedRadio(let track):
                track.videoID
            case .external(let track):
                track.mediaID
            }
        }

        var fingerprint: String {
            switch self {
            case .song(let song):
                "\(song.title.lowercased())|\(song.artistsDisplay.lowercased())"
            case .video(let video):
                "\(video.title.lowercased())|\(video.author.lowercased())"
            case .cachedRadio(let track):
                track.fingerprint
            case .external(let track):
                "\(track.title.lowercased())|\(track.artist.lowercased())"
            }
        }
    }

    struct PreparedQueuePlayback {
        let mediaID: String
        let item: AVPlayerItem
        let playbackCandidates: [PlaybackCandidate]
        let preparedAt: Date
        let title: String
        let artist: String
        let artworkURL: URL?
        let streamingService: StreamingService
        let qualityLabel: String
        let codecLabel: String
        let albumName: String?
        let isExplicit: Bool
        let durationHint: Int?
    }

    struct QueueMusicPreloadInput {
        let mediaID: String
        let title: String
        let artist: String
        let albumName: String?
        let artworkURL: URL?
        let isExplicit: Bool
        let durationHint: Int?
        let youtubeDebugSource: String
    }

}
