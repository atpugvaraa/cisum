import Foundation
import Player
import Services

public final class PlaybackDomain {
    internal let playerViewModel: PlayerViewModel
    internal let playbackControlSettings: PlaybackControlSettings
    internal let playbackMetricsStore: PlaybackMetricsStore
    #if os(iOS)
    internal let systemVolumeController: SystemVolumeController
    internal let volumeButtonSkipController: VolumeButtonSkipController
    #endif
    internal let radioSessionStore: RadioSessionStore
    internal let artworkVideoProcessor: ArtworkVideoProcessor
    #if os(iOS)
    internal let artworkColorExtractor: ArtworkDominantColorExtractor
    #endif

    #if os(iOS)
    public init(
        playerViewModel: PlayerViewModel,
        playbackControlSettings: PlaybackControlSettings,
        playbackMetricsStore: PlaybackMetricsStore,
        systemVolumeController: SystemVolumeController,
        volumeButtonSkipController: VolumeButtonSkipController,
        radioSessionStore: RadioSessionStore,
        artworkVideoProcessor: ArtworkVideoProcessor,
        artworkColorExtractor: ArtworkDominantColorExtractor
    ) {
        self.playerViewModel = playerViewModel
        self.playbackControlSettings = playbackControlSettings
        self.playbackMetricsStore = playbackMetricsStore
        self.systemVolumeController = systemVolumeController
        self.volumeButtonSkipController = volumeButtonSkipController
        self.artworkColorExtractor = artworkColorExtractor
        self.radioSessionStore = radioSessionStore
        self.artworkVideoProcessor = artworkVideoProcessor
    }
    #else
    public init(
        playerViewModel: PlayerViewModel,
        playbackControlSettings: PlaybackControlSettings,
        playbackMetricsStore: PlaybackMetricsStore,
        radioSessionStore: RadioSessionStore,
        artworkVideoProcessor: ArtworkVideoProcessor
    ) {
        self.playerViewModel = playerViewModel
        self.playbackControlSettings = playbackControlSettings
        self.playbackMetricsStore = playbackMetricsStore
        self.radioSessionStore = radioSessionStore
        self.artworkVideoProcessor = artworkVideoProcessor
    }
    #endif

    public func interface(streamingProviderSettings: StreamingProviderSettings) -> PlaybackInterface {
        #if os(iOS)
        return PlaybackInterface(
            playbackControlSettings: playbackControlSettings,
            playbackMetricsStore: playbackMetricsStore,
            streamingProviderSettings: streamingProviderSettings,
//            systemVolumeController: systemVolumeController,
//            volumeButtonSkipController: volumeButtonSkipController,
//            artworkColorExtractor: artworkColorExtractor,
            radioSessionStore: radioSessionStore,
            artworkVideoProcessor: artworkVideoProcessor,
            playerViewModel: playerViewModel
        )
        #else
        return PlaybackInterface(
            playbackControlSettings: playbackControlSettings,
            playbackMetricsStore: playbackMetricsStore,
            streamingProviderSettings: streamingProviderSettings,
            radioSessionStore: radioSessionStore,
            artworkVideoProcessor: artworkVideoProcessor,
            playerViewModel: playerViewModel
        )
        #endif
    }
}
