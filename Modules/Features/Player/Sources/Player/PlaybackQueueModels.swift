import Foundation
import Models
import Services
import YouTubeSDK
import AVFoundation

public struct QueueCandidateSnapshot: Sendable, Hashable, Codable {
    public let streamKind: String
    public let mimeType: String?
    public let itag: Int?
    public let expiresAt: Date?
    public let isCompatible: Bool

    public init(streamKind: String, mimeType: String?, itag: Int?, expiresAt: Date?, isCompatible: Bool) {
        self.streamKind = streamKind
        self.mimeType = mimeType
        self.itag = itag
        self.expiresAt = expiresAt
        self.isCompatible = isCompatible
    }

    public init(_ candidate: PlaybackCandidate) {
        self.init(
            streamKind: candidate.streamKind.rawValue,
            mimeType: candidate.mimeType,
            itag: candidate.itag,
            expiresAt: candidate.expiresAt,
            isCompatible: candidate.isCompatible
        )
    }
}

public struct QueueIdentitySnapshot: Sendable, Hashable, Codable {
    public let canonicalID: String
    public let activeRepresentationKey: String?
    public let hydrationState: [String]
    public let candidateSnapshot: [QueueCandidateSnapshot]

    public init(
        canonicalID: String,
        activeRepresentationKey: String? = nil,
        hydrationState: [String] = [],
        candidateSnapshot: [QueueCandidateSnapshot] = []
    ) {
        self.canonicalID = canonicalID
        self.activeRepresentationKey = activeRepresentationKey
        self.hydrationState = hydrationState
        self.candidateSnapshot = candidateSnapshot
    }
}

public struct CachedRadioTrack: Identifiable, Sendable, Equatable {
    public var id: String { videoID }
    public let videoID: String
    public let title: String
    public let artist: String
    public let albumName: String?
    public let thumbnailURL: URL?
    public let isExplicit: Bool

    public var fingerprint: String {
        "\(title.lowercased())|\(artist.lowercased())"
    }

    public init(
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

    public init(song: YouTubeMusicSong) {
        self.videoID = song.videoId
        self.title = song.title
        self.artist = song.artistsDisplay
        self.albumName = song.album
        self.thumbnailURL = song.thumbnailURL
        self.isExplicit = song.isExplicit
    }
    
    @MainActor
    public init(cached: RadioSessionStore.CachedTrack) {
        self.videoID = cached.videoID
        self.title = cached.title
        self.artist = cached.artist
        self.albumName = cached.albumName
        self.thumbnailURL = cached.thumbnailURL
        self.isExplicit = cached.isExplicit
    }
    
    @MainActor
    public var persisted: RadioSessionStore.CachedTrack {
        RadioSessionStore.CachedTrack(
            videoID: videoID,
            title: title,
            artist: artist,
            albumName: albumName,
            thumbnailURLString: thumbnailURL?.absoluteString,
            isExplicit: isExplicit
        )
    }

    public var queueIdentity: QueueIdentitySnapshot {
        QueueIdentitySnapshot(
            canonicalID: canonicalQueueID(for: fingerprint, fallback: videoID),
            activeRepresentationKey: nil,
            hydrationState: ["metadataResolved"],
            candidateSnapshot: []
        )
    }
}

public enum PlaybackQueueEntry: Equatable, Sendable {
    case song(YouTubeMusicSong)
    case video(YouTubeVideo)
    case cachedRadio(CachedRadioTrack)
    case external(ExternalQueueTrack)

    public static func == (lhs: PlaybackQueueEntry, rhs: PlaybackQueueEntry) -> Bool {
        switch (lhs, rhs) {
        case (.song(let l), .song(let r)): return l.id == r.id
        case (.video(let l), .video(let r)): return l.id == r.id
        case (.cachedRadio(let l), .cachedRadio(let r)): return l.id == r.id
        case (.external(let l), .external(let r)): return l == r
        default: return false
        }
    }

    public var mediaID: String {
        switch self {
        case .song(let song):
            return song.videoId
        case .video(let video):
            return video.id
        case .cachedRadio(let track):
            return track.videoID
        case .external(let track):
            return track.mediaID
        }
    }

    public var fingerprint: String {
        switch self {
        case .song(let song):
            return "\(song.title.lowercased())|\(song.artistsDisplay.lowercased())"
        case .video(let video):
            return "\(video.title.lowercased())|\(video.author.lowercased())"
        case .cachedRadio(let track):
            return track.fingerprint
        case .external(let track):
            return "\(track.title.lowercased())|\(track.artist.lowercased())"
        }
    }
    
    public var title: String {
        switch self {
        case .song(let song): return song.title
        case .video(let video): return video.title
        case .cachedRadio(let track): return track.title
        case .external(let track): return track.title
        }
    }
    
    public var artist: String {
        switch self {
        case .song(let song): return song.artistsDisplay
        case .video(let video): return video.author
        case .cachedRadio(let track): return track.artist
        case .external(let track): return track.artist
        }
    }
    
    public var artworkURL: URL? {
        switch self {
        case .song(let song): return song.thumbnailURL
        case .video(let video): 
            if let urlString = video.thumbnailURL {
                return URL(string: urlString)
            }
            return nil
        case .cachedRadio(let track): return track.thumbnailURL
        case .external(let track): return track.artworkURL
        }
    }
    
    public var isExplicit: Bool {
        switch self {
        case .song(let song): return song.isExplicit
        case .video: return false
        case .cachedRadio(let track): return track.isExplicit
        case .external(let track): return track.isExplicit
        }
    }

    public var queueIdentity: QueueIdentitySnapshot {
        switch self {
        case .song(let song):
            return QueueIdentitySnapshot(
                canonicalID: canonicalQueueID(for: "\(song.title.lowercased())|\(song.artistsDisplay.lowercased())", fallback: song.videoId),
                activeRepresentationKey: nil,
                hydrationState: ["metadataResolved"],
                candidateSnapshot: []
            )
        case .video(let video):
            let title = video.title.lowercased()
            let artist = video.author.lowercased()
            return QueueIdentitySnapshot(
                canonicalID: canonicalQueueID(for: "\(title)|\(artist)", fallback: video.id),
                activeRepresentationKey: nil,
                hydrationState: ["metadataResolved"],
                candidateSnapshot: []
            )
        case .cachedRadio(let track):
            return track.queueIdentity
        case .external(let track):
            return QueueIdentitySnapshot(
                canonicalID: canonicalQueueID(for: "\(track.title.lowercased())|\(track.artist.lowercased())", fallback: track.mediaID),
                activeRepresentationKey: nil,
                hydrationState: ["metadataResolved"],
                candidateSnapshot: []
            )
        }
    }
}

public struct PreparedQueuePlayback {
    public let mediaID: String
    public let item: AVPlayerItem
    public let playbackCandidates: [PlaybackCandidate]
    public let preparedAt: Date
    public let title: String
    public let artist: String
    public let artworkURL: URL?
    public let streamingService: PlayerViewModel.StreamingService
    public let qualityLabel: String
    public let codecLabel: String
    public let albumName: String?
    public let isExplicit: Bool
    public let durationHint: Int?

    public var queueIdentity: QueueIdentitySnapshot {
        let canonicalTitle = title.lowercased()
        let canonicalArtist = artist.lowercased()
        return QueueIdentitySnapshot(
            canonicalID: canonicalQueueID(for: "\(canonicalTitle)|\(canonicalArtist)", fallback: mediaID),
            activeRepresentationKey: nil,
            hydrationState: ["metadataResolved"],
            candidateSnapshot: playbackCandidates.map(QueueCandidateSnapshot.init)
        )
    }
}

public struct QueueMusicPreloadInput {
    public let mediaID: String
    public let title: String
    public let artist: String
    public let albumName: String?
    public let artworkURL: URL?
    public let isExplicit: Bool
    public let durationHint: Int?
    public let youtubeDebugSource: String
}

func canonicalQueueID(for fingerprint: String, fallback: String) -> String {
    let normalized = fingerprint.trimmingCharacters(in: .whitespacesAndNewlines)
    return normalized.isEmpty ? fallback : normalized
}
