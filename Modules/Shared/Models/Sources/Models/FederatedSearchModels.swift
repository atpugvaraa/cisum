import Foundation
import YouTubeSDK

public enum FederatedService: String, CaseIterable, Identifiable, Sendable {
    case youtube = "YouTube"
    case youtubeMusic = "YouTube Music"
    case spotify = "Spotify"

    public var id: FederatedService { self }
}

public enum FederatedSectionState: Equatable, Sendable {
    case idle
    case loading
    case success
    case error(String)
}

public struct FederatedSearchSection: Identifiable, Sendable {
    public let service: FederatedService
    public var state: FederatedSectionState
    public var items: [FederatedSearchItem]

    public var id: FederatedService { service }

    public init(service: FederatedService, state: FederatedSectionState, items: [FederatedSearchItem]) {
        self.service = service
        self.state = state
        self.items = items
    }

    public static var defaultSections: [FederatedSearchSection] {
        FederatedService.allCases.map {
            FederatedSearchSection(service: $0, state: .idle, items: [])
        }
    }
}

public struct SpotifySearchTrack: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let artistName: String
    public let albumName: String?
    public let artworkURL: URL?
    public let durationSeconds: TimeInterval
    public let previewURL: URL?

    public init(id: String, title: String, artistName: String, albumName: String?, artworkURL: URL?, durationSeconds: TimeInterval, previewURL: URL?) {
        self.id = id
        self.title = title
        self.artistName = artistName
        self.albumName = albumName
        self.artworkURL = artworkURL
        self.durationSeconds = durationSeconds
        self.previewURL = previewURL
    }
}

public enum FederatedSearchPayload: Sendable {
    case youtubeVideo(YouTubeVideo)
    case youtubeMusic(YouTubeMusicSong)
    case spotify(SpotifySearchTrack)
    case spotifyArtist(SpotifySearchArtist)
    case spotifyPlaylist(SpotifySearchPlaylist)
}

public struct FederatedSearchItem: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let artworkURL: URL?
    public let durationSeconds: TimeInterval?
    public let isPlayable: Bool
    public let isExplicit: Bool
    public let audioQualityLabel: String?
    public let audioCodecLabel: String?
    public let payload: FederatedSearchPayload

    public init(id: String, title: String, subtitle: String, artworkURL: URL?, durationSeconds: TimeInterval?, isPlayable: Bool, isExplicit: Bool, audioQualityLabel: String?, audioCodecLabel: String?, payload: FederatedSearchPayload) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.artworkURL = artworkURL
        self.durationSeconds = durationSeconds
        self.isPlayable = isPlayable
        self.isExplicit = isExplicit
        self.audioQualityLabel = audioQualityLabel
        self.audioCodecLabel = audioCodecLabel
        self.payload = payload
    }

    public nonisolated var service: FederatedService {
        switch payload {
        case .youtubeVideo:
            return .youtube
        case .youtubeMusic:
            return .youtubeMusic
        case .spotify, .spotifyArtist, .spotifyPlaylist:
            return .spotify
        }
    }

    public var displayDuration: String? {
        guard let seconds = durationSeconds else { return nil }
        let min = Int(seconds) / 60
        let sec = Int(seconds) % 60
        return String(format: "%d:%02d", min, sec)
    }

    public var displayArtist: String {
        if let first = subtitle.split(separator: "•").first {
            let artist = String(first).trimmingCharacters(in: .whitespacesAndNewlines)
            if !artist.isEmpty {
                return artist
            }
        }
        return subtitle
    }
}

public struct ExternalStreamPayload: Sendable {
    public let mediaID: String
    public let streamURL: URL
    public let title: String
    public let artist: String
    public let artworkURL: URL?
    public let service: FederatedService
    public let qualityLabel: String
    public let codecLabel: String

    public init(mediaID: String, streamURL: URL, title: String, artist: String, artworkURL: URL?, service: FederatedService, qualityLabel: String, codecLabel: String) {
        self.mediaID = mediaID
        self.streamURL = streamURL
        self.title = title
        self.artist = artist
        self.artworkURL = artworkURL
        self.service = service
        self.qualityLabel = qualityLabel
        self.codecLabel = codecLabel
    }
}

public enum FederatedSearchError: LocalizedError, Sendable {
    case providerUnavailable(String)
    case spotifyCredentialsMissing
    case noPlayableStream(String)

    public var errorDescription: String? {
        switch self {
        case .providerUnavailable(let message):
            return message
        case .spotifyCredentialsMissing:
            return "Spotify is not connected. Sign in via Settings → Spotify to enable full-quality search."
        case .noPlayableStream(let message):
            return message
        }
    }
}

public struct SpotifySearchArtist: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let artworkURL: URL?
    public let genres: [String]

    public init(id: String, name: String, artworkURL: URL?, genres: [String]) {
        self.id = id
        self.name = name
        self.artworkURL = artworkURL
        self.genres = genres
    }
}

public struct SpotifySearchPlaylist: Identifiable, Sendable {
    public let id: String
    public let uri: String
    public let name: String
    public let ownerName: String
    public let artworkURL: URL?
    public let totalTracks: Int?

    public init(id: String, uri: String, name: String, ownerName: String, artworkURL: URL?, totalTracks: Int?) {
        self.id = id
        self.uri = uri
        self.name = name
        self.ownerName = ownerName
        self.artworkURL = artworkURL
        self.totalTracks = totalTracks
    }
}
