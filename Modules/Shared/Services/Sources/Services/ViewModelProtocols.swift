import Foundation
import Observation
import SwiftUI
import Models
import YouTubeSDK

@MainActor
public protocol PlayerViewModelInterface: AnyObject, Observable {
    // Basic Track Info
    var currentTitle: String { get }
    var currentArtist: String { get }
    var currentImageURL: URL? { get }
    var currentAccentColor: Color { get }
    var isExplicit: Bool { get }
    var currentVideoId: String? { get }
    
    // Playback State
    var isPlaying: Bool { get }
    var duration: Double { get }
    var currentTime: Double { get }
    var canSkipForward: Bool { get }
    var canSkipBackward: Bool { get }
    
    // Lyrics State
    var isLyricsVisible: Bool { get set }
    var lyricsState: LyricsState { get }
    var syncedLyricsLines: [TimedLyricLine] { get }
    var currentSyncedLyricIndex: Int? { get }
    var plainLyricsText: String? { get }
    
    // Playback Actions
    func togglePlayPause()
    func skipToNext()
    func skipToPrevious()
    func seek(to timestamp: Double)
    func load(song: YouTubeMusicSong, preserveQueue: Bool)
    func load(video: YouTubeVideo, preserveQueue: Bool)
    func load(external track: ExternalQueueTrack, preserveQueue: Bool)
    
    // Hi-Res Actions
    var isCheckingHiResAvailability: Bool { get }
    var canSwitchToHiResVersion: Bool { get }
    func checkForHiResVersion() async
    func switchToHiResVersionIfAvailable()
}

@MainActor
public protocol SearchViewModelInterface: AnyObject, Observable {
    var searchText: String { get set }
    var suggestions: [String] { get }
    var state: SearchState { get }
    var searchScope: SearchScope { get set }
    
    // Results
    var musicResults: [YouTubeMusicSong] { get }
    var videoResults: [YouTubeSearchResult] { get }
    var spotifyTrackResults: [FederatedSearchItem] { get }
    var spotifyArtistResults: [FederatedSearchItem] { get }
    var spotifyPlaylistResults: [FederatedSearchItem] { get }
    var unifiedTopResults: [FederatedSearchItem] { get }
    var youMightLikeResults: [FederatedSearchItem] { get }
    var hiddenFallbackMap: [String: FederatedSearchItem] { get }
    
    func applySuggestion(_ suggestion: String)
    func recordSuccessfulPlayFromCurrentQuery()
    func resolveExternalStream(for item: FederatedSearchItem) async throws -> ExternalStreamPayload?
    
    // Pagination helpers
    var isVideoPaginationLoading: Bool { get }
    func loadMoreVideosIfNeeded(for item: YouTubeSearchResult)
}

// MARK: - Search Support Types

public enum SearchScope: String, CaseIterable, Identifiable, Sendable {
    case music = "Music"
    case video = "Videos"
    
    public var id: String { rawValue }
}

public enum SearchState: Equatable, Sendable {
    case idle
    case loading
    case error(String)
    case success
}

// MARK: - External Track Support

public struct ExternalQueueTrack {
    public let mediaID: String
    public let title: String
    public let artist: String
    public let artworkURL: URL?
    public let service: FederatedService
    public let isExplicit: Bool
    public let qualityLabelHint: String?
    public let codecLabelHint: String?
    public let resolvePayload: @MainActor () async throws -> ExternalStreamPayload
    
    public init(mediaID: String, title: String, artist: String, artworkURL: URL?, service: FederatedService, isExplicit: Bool, qualityLabelHint: String?, codecLabelHint: String?, resolvePayload: @escaping @MainActor () async throws -> ExternalStreamPayload) {
        self.mediaID = mediaID
        self.title = title
        self.artist = artist
        self.artworkURL = artworkURL
        self.service = service
        self.isExplicit = isExplicit
        self.qualityLabelHint = qualityLabelHint
        self.codecLabelHint = codecLabelHint
        self.resolvePayload = resolvePayload
    }
}
