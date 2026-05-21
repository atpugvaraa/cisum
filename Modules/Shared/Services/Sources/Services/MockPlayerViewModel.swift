import Foundation
import Observation
import SwiftUI
import Models
import YouTubeSDK

#if DEBUG
@MainActor
public final class MockPlayerViewModel: PlayerViewModelInterface {
    public var currentTitle: String = "Preview Song"
    public var currentArtist: String = "Preview Artist"
    public var currentImageURL: URL? = nil
    public var currentAccentColor: Color = .pink
    public var isExplicit: Bool = false
    public var currentVideoId: String? = "123"
    
    public var isPlaying: Bool = true
    public var duration: Double = 200
    public var currentTime: Double = 50
    public var canSkipForward: Bool = true
    public var canSkipBackward: Bool = true
    
    public var isLyricsVisible: Bool = false
    public var lyricsState: LyricsState = .unavailable("Preview")
    public var syncedLyricsLines: [TimedLyricLine] = []
    public var currentSyncedLyricIndex: Int? = nil
    public var plainLyricsText: String? = nil
    
    public func togglePlayPause() {}
    public func skipToNext() {}
    public func skipToPrevious() {}
    public func seek(to timestamp: Double) {}
    public func load(song: YouTubeMusicSong, preserveQueue: Bool) {}
    public func load(video: YouTubeVideo, preserveQueue: Bool) {}
    public func load(external track: ExternalQueueTrack, preserveQueue: Bool) {}
    
    public var isCheckingHiResAvailability: Bool = false
    public var canSwitchToHiResVersion: Bool = false
    public var hiResAvailabilityMessage: String? = nil
    public func checkForHiResVersion() async {}
    public func switchToHiResVersionIfAvailable() {}
    
    public var artworkVideoStatus: ArtworkVideoProcessingStatus = .idle
    public var animatedArtworkVideoURL: URL? = nil
    public var artworkVideoProgress: Double? = nil
    public var artworkVideoError: String? = nil
    
    public var lyricsAttribution: String? = nil
    
    public init() {}
}

public extension PlaybackServices {
    static var preview: PlaybackServices {
        PlaybackServices(
            playbackControlSettings: PlaybackControlSettings.shared,
            playbackMetricsStore: PlaybackMetricsStore.shared,
            lastFMSettings: LastFMSettings.shared,
            lastFMScrobbler: LastFMScrobbler(authService: AuthService()),
            listeningHistoryStore: ListeningHistoryStore.preview,
            streamingProviderSettings: StreamingProviderSettings.shared,
            radioSessionStore: RadioSessionStore.shared,
            artworkVideoProcessor: ArtworkVideoProcessor.shared,
            playerViewModel: MockPlayerViewModel()
        )
    }
}
#endif
