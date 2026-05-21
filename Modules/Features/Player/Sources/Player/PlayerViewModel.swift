import Utilities
//
//  PlayerViewModel.swift
//  cisum
//
//  Created by Aarav Gupta on 03/12/25.
//

import SwiftUI
import AVKit
import AVFoundation
import MediaPlayer
import YouTubeSDK

#if canImport(iTunesKit)
import iTunesKit
#endif

import Services
import Models
import DesignSystem

#if canImport(LyricsKit)
import LyricsKit
#endif

#if os(iOS)
import UIKit
#endif

import Services

@Observable
@MainActor
public final class PlayerViewModel: PlayerViewModelInterface {
    public enum CachePolicy {
        public static let playbackURLTTL: TimeInterval = 60 * 2
        public static let playbackMinimumRemainingLifetime: TimeInterval = 60 * 3
        public static let preparedYouTubeMaxAge: TimeInterval = 75
        public static let highQualityArtworkTTL: TimeInterval = 60 * 60 * 24 * 14
        public static let motionArtworkSourceTTL: TimeInterval = 60 * 60 * 24
    }

    private enum Diagnostics {
        static let verbosePlaybackLogsEnabled = false
        static let verboseArtworkLogsEnabled = false
    }

    private enum PlaybackRecoveryPolicy {
        static let maxAttemptsPerMediaID = 2
    }

    private enum RadioAutoplayPolicy {
        static let queueLowWatermark = 5
        static let maxSeedQueueTracks = 80
        static let minCachedTracksWithoutContinuation = 8
        static let minSeedTracksBeforePlaylistHydration = 16
    }


    public enum PlaybackQueueSource: String {
        case detached
        case searchMusic
        case searchVideo
        case searchExternal
        case radioAutoplay
    }

    public enum StreamingService: String {
        case youtube = "YouTube"
        case youtubeMusic = "YouTube Music"
        case spotify = "Spotify"
        case external = "External"
    }


    public struct QueuePreviewItem: Identifiable, Equatable {
        public let id: String
        public let title: String
        public let subtitle: String
        public let artworkURL: URL?
        
        public init(id: String, title: String, subtitle: String, artworkURL: URL?) {
            self.id = id
            self.title = title
            self.subtitle = subtitle
            self.artworkURL = artworkURL
        }
    }

    @Observable
    @MainActor
    public final class PlaybackProgressState {
        public var duration: Double = 0.0
        public var currentTime: Double = 0.0
        
        public init() {}
    }

    private struct TrackPresentationState {
        let mediaID: String
        let title: String
        let artist: String
        let albumName: String?
        let artworkURL: URL?
        let isExplicit: Bool
        let streamingService: StreamingService
        let qualityLabel: String
        let codecLabel: String
        let durationHint: Int?
    }

    public struct PrioritizedCandidateResolution {
        public let candidates: [PlaybackCandidate]
        public let hiResPayload: ExternalStreamPayload?
        
        public init(candidates: [PlaybackCandidate], hiResPayload: ExternalStreamPayload?) {
            self.candidates = candidates
            self.hiResPayload = hiResPayload
        }
    }


    // MARK: - State
    public var player: AVPlayer { playbackEngine.player }
    private let youtube: YouTube
    private let artworkVideoProcessor: ArtworkVideoProcessor
    public var currentVideoId: String?
    public var playbackError: String?
    public var animatedArtworkVideoURL: URL?
    public var artworkVideoProgress: Double?
    public var artworkVideoStatus: ArtworkVideoProcessingStatus = .idle
    public var artworkVideoError: String?

    // Track Info
    public var currentTitle: String = "Not Playing"
    public var currentArtist: String = ""
    public var currentImageURL: URL?
    public var currentAccentColor: Color = .cisumAccent
    public var isExplicit: Bool = false
    public var currentStreamingServiceName: String = StreamingService.youtubeMusic.rawValue
    public var currentAudioQualityLabel: String = "Adaptive"
    public var currentAudioCodecLabel: String = "HLS"
    public var hiResAvailabilityMessage: String?
    public var isCheckingHiResAvailability: Bool = false
    public var canSwitchToHiResVersion: Bool {
        pendingHiResPayload != nil
    }
    // MARK: - Controllers
    public let playbackEngine = PlaybackEngine()
    public let lyricsController = LyricsController()
    public let artworkController = ArtworkController()
    public let queueManager = QueueManager()

    // MARK: - Delegated Properties
    public var isPlaying: Bool { playbackEngine.isPlaying }
    public var currentTime: Double { playbackEngine.currentTime }
    public var duration: Double { playbackEngine.duration }
    public var isLyricsVisible: Bool {
        get { lyricsController.isVisible }
        set { lyricsController.isVisible = newValue }
    }
    public var lyricsState: LyricsState {
        lyricsController.state
    }
    public var syncedLyricsLines: [TimedLyricLine] { lyricsController.syncedLines }
    public var plainLyricsText: String? { lyricsController.plainText }
    public var lyricsAttribution: String? { lyricsController.attribution }
    public var progressState = PlaybackProgressState()

    // Queue
    public var queueSource: PlaybackQueueSource = .detached
    public var queuePosition: Int?
    public var queueCount: Int = 0
    public var canSkipForward: Bool {
        hasNextTrackInQueue
    }
    public var canSkipBackward: Bool {
        guard currentVideoId != nil else { return false }
        return hasPreviousTrackInQueue || currentTime > 5
    }

    public var queuePreviewItems: [QueuePreviewItem] = []

    var currentQueuePreviewIndex: Int? {
        queuePosition
    }

    var previousQueuePreviewItem: QueuePreviewItem? {
        guard let queuePosition,
              queuePosition > 0,
              queuePreviewItems.indices.contains(queuePosition - 1) else {
            return nil
        }

        return queuePreviewItems[queuePosition - 1]
    }

    var nextQueuePreviewItem: QueuePreviewItem? {
        guard let queuePosition,
              queuePreviewItems.indices.contains(queuePosition + 1) else {
            return nil
        }

        return queuePreviewItems[queuePosition + 1]
    }

    // Private
    private var timeObserver: Any?
    private var currentLoadTask: Task<Void, Never>?
    var artworkLoadTask: Task<Void, Never>?
    private var artworkVideoTask: Task<Void, Never>?
    var lyricsLoadTask: Task<Void, Never>?
    private var playbackRecoveryTask: Task<Void, Never>?
    private var exhaustiveRetryTask: Task<Void, Never>?
    /// Tracks which mediaIDs have already had exhaustiveRetry attempted.
    /// Prevents the infinite loop: fail → retry → same URL → fail → retry...
    private var exhaustiveRetryAttemptedIDs: Set<String> = []
    private var playbackRecoveryAttemptCounts: [String: Int] = [:]
    private var playbackCandidates: [PlaybackCandidate] = []
    private var playbackCandidateIndex: Int = 0
    private var playbackCandidatesMediaID: String?
    private var pendingPlaybackFormatOverride: (quality: String, codec: String)?
    private var currentAlbumNameHint: String?
    var playbackQueue: [PlaybackQueueEntry] = [] {
        didSet {
            updateQueuePreviewItems()
        }
    }
    
    private func updateQueuePreviewItems() {
        let entries = playbackQueue
        Task {
            let items = await self.mapQueueEntriesToPreview(entries)
            await MainActor.run {
                self.queuePreviewItems = items
            }
        }
    }

    nonisolated private func mapQueueEntriesToPreview(_ entries: [PlaybackQueueEntry]) async -> [QueuePreviewItem] {
        return entries.map { entry in
            switch entry {
            case .song(let song):
                return QueuePreviewItem(
                    id: song.videoId,
                    title: normalizedMusicDisplayTitle(song.title, artist: song.artistsDisplay),
                    subtitle: normalizedMusicDisplayArtist(song.artistsDisplay, title: song.title),
                    artworkURL: song.thumbnailURL
                )
            case .video(let video):
                return QueuePreviewItem(
                    id: video.id,
                    title: normalizedMusicDisplayTitle(video.title, artist: video.author),
                    subtitle: normalizedMusicDisplayArtist(video.author, title: video.title),
                    artworkURL: normalizedArtworkURL(from: video.thumbnailURL)
                )
            case .cachedRadio(let track):
                return QueuePreviewItem(
                    id: track.videoID,
                    title: normalizedMusicDisplayTitle(track.title, artist: track.artist),
                    subtitle: normalizedMusicDisplayArtist(track.artist, title: track.title),
                    artworkURL: track.thumbnailURL
                )
            case .external(let track):
                return QueuePreviewItem(
                    id: track.mediaID,
                    title: normalizedMusicDisplayTitle(track.title, artist: track.artist),
                    subtitle: normalizedMusicDisplayArtist(track.artist, title: track.title),
                    artworkURL: track.artworkURL
                )
            }
        }
    }
    private var currentItemStatusObservation: NSKeyValueObservation?
    private var currentItemEndObserver: NSObjectProtocol?
    private let remoteCommandCenter = MPRemoteCommandCenter.shared()
    private let metadataCache: any VideoMetadataCaching
    #if canImport(iTunesKit)
    let itunes = iTunesKit()
    #endif
    let mediaCacheStore: MediaCacheStore
    private let settings: PrefetchSettings
    private let playbackMetricsStore: any PlaybackMetricsRecording
    private let lastFMScrobbler: LastFMScrobbler
    private let lastFMSettings: LastFMSettings
    private let listeningHistoryStore: ListeningHistoryStore
    private let streamingProviderSettings: StreamingProviderSettings
    private let radioSessionStore: RadioSessionStore
    private var currentListeningHistoryEntry: ListeningHistoryEntry?
    private var activeScrobbleSessionMediaID: String?
    private var hasSubmittedScrobbleForActiveSession = false
    private var lastFMScrobbleTask: Task<Void, Never>?
#if os(iOS)
    let artworkColorExtractor: any ArtworkColorExtracting
#endif

#if os(iOS)
    var nowPlayingState = NowPlayingState()
    var lastPublishedNowPlayingState: NowPlayingState?
    var currentArtworkResource: CachedNowPlayingArtworkResource?
    var currentArtworkMediaID: String?
    var artworkCache: [String: CachedNowPlayingArtworkResource] = [:]
    var artworkAccentCache: [String: (artworkURL: URL, color: Color)] = [:]
    var accentLoadTask: Task<Void, Never>?

    var interruptionObserver: NSObjectProtocol?
    var routeChangeObserver: NSObjectProtocol?
    var wasPlayingBeforeInterruption = false
#endif

    private var hasNextTrackInQueue: Bool {
        guard let queuePosition else { return false }
        return queuePosition + 1 < playbackQueue.count
    }

    private var hasPreviousTrackInQueue: Bool {
        guard let queuePosition else { return false }
        return queuePosition > 0
    }

    private var radioSeedVideoID: String?
    private var radioPlaylistID: String?
    private var radioContinuationToken: String?
    private var radioAutoplayTask: Task<Void, Never>?
    private var radioContinuationTask: Task<Void, Never>?
    private var isLoadingRadioContinuation = false
    var preparedNextPlayback: PreparedQueuePlayback?
    var nextPlaybackPreloadTask: Task<Void, Never>?
    var preloadingNextMediaID: String?
    var externalPayloadCache: [String: ExternalStreamPayload] = [:]
    private var pendingHiResPayload: ExternalStreamPayload?

#if os(iOS)
    public init(
        youtube: YouTube,
        settings: PrefetchSettings,
        artworkVideoProcessor: ArtworkVideoProcessor,
        metadataCache: any VideoMetadataCaching,
        mediaCacheStore: MediaCacheStore,
        playbackMetricsStore: any PlaybackMetricsRecording,
        lastFMScrobbler: LastFMScrobbler,
        lastFMSettings: LastFMSettings,
        listeningHistoryStore: ListeningHistoryStore,
        streamingProviderSettings: StreamingProviderSettings,
        radioSessionStore: RadioSessionStore,
        artworkColorExtractor: any ArtworkColorExtracting
    ) {
        self.youtube = youtube
        self.settings = settings
        self.artworkVideoProcessor = artworkVideoProcessor
        self.metadataCache = metadataCache
        self.mediaCacheStore = mediaCacheStore
        self.playbackMetricsStore = playbackMetricsStore
        self.lastFMScrobbler = lastFMScrobbler
        self.lastFMSettings = lastFMSettings
        self.listeningHistoryStore = listeningHistoryStore
        self.streamingProviderSettings = streamingProviderSettings
        self.radioSessionStore = radioSessionStore
        self.artworkColorExtractor = artworkColorExtractor

        finishInitialization()
    }
#else
    public init(
        youtube: YouTube,
        settings: PrefetchSettings,
        artworkVideoProcessor: ArtworkVideoProcessor,
        metadataCache: any VideoMetadataCaching,
        mediaCacheStore: MediaCacheStore,
        playbackMetricsStore: any PlaybackMetricsRecording,
        lastFMScrobbler: LastFMScrobbler,
        lastFMSettings: LastFMSettings,
        listeningHistoryStore: ListeningHistoryStore,
        streamingProviderSettings: StreamingProviderSettings,
        radioSessionStore: RadioSessionStore
    ) {
        self.youtube = youtube
        self.settings = settings
        self.artworkVideoProcessor = artworkVideoProcessor
        self.metadataCache = metadataCache
        self.mediaCacheStore = mediaCacheStore
        self.playbackMetricsStore = playbackMetricsStore
        self.lastFMScrobbler = lastFMScrobbler
        self.lastFMSettings = lastFMSettings
        self.listeningHistoryStore = listeningHistoryStore
        self.streamingProviderSettings = streamingProviderSettings
        self.radioSessionStore = radioSessionStore

        finishInitialization()
    }
#endif

    private func finishInitialization() {
        configureAudioSession()
        configurePlayerForBackgroundPlayback()
        setupRemoteCommands()
        
        playbackEngine.onProgressUpdate = { [weak self] in
            guard let self else { return }
            self.handleProgressUpdate()
        }
        
        setupAudioLifecycleObservers()

    #if os(iOS)
        setupVolumeButtonSkip()
    #endif

        Color.resetDynamicAccent()
        currentAccentColor = Color.dynamicAccent
    }

    private func handleProgressUpdate() {
        let previousCanSkipBackward = self.canSkipBackward
        
        if self.canSkipBackward != previousCanSkipBackward {
            self.updateRemoteCommandState()
        }
        maybeSubmitLastFMScrobble()
    }

    // MARK: - Playback Session State

    private func preparePlaybackSession(for state: TrackPresentationState, preserveQueue: Bool) {
        if !preserveQueue {
            clearQueueContext()
        }

        resetHiResAvailabilityState()
        applyTrackPresentation(state)
        resetPlaybackRuntimeState(for: state.mediaID)
        startTrackAncillaryWork(for: state)
    }

    private func applyTrackPresentation(_ state: TrackPresentationState) {
        currentTitle = state.title
        currentArtist = state.artist
        currentAlbumNameHint = state.albumName
        currentImageURL = state.artworkURL
        isExplicit = state.isExplicit
        currentStreamingServiceName = state.streamingService.rawValue
        currentAudioQualityLabel = state.qualityLabel
        currentAudioCodecLabel = state.codecLabel
        pendingPlaybackFormatOverride = nil
        currentVideoId = state.mediaID
    }

    private func resetPlaybackRuntimeState(for mediaID: String) {
        playbackError = nil
        playbackEngine.resetProgress()
        resetPlaybackCandidates(for: mediaID)
        resetPlaybackRecoveryState(for: mediaID)
        playbackRecoveryTask?.cancel()
        playbackRecoveryTask = nil
        exhaustiveRetryTask?.cancel()
        exhaustiveRetryTask = nil
        // Reset the retry guard so the new track gets one exhaustive retry attempt.
        // We intentionally keep IDs from *other* tracks so we don't re-enter for the previous track.
        exhaustiveRetryAttemptedIDs.remove(mediaID)
        resetArtworkVideoState()
#if os(iOS)
        artworkLoadTask?.cancel()
        accentLoadTask?.cancel()
        applyCachedArtworkIfAvailable(for: mediaID)
#endif
    }

    private func startTrackAncillaryWork(for state: TrackPresentationState) {
        startListeningSessionIfNeeded(for: state)
        startLyricsResolution(
            mediaID: state.mediaID,
            title: state.title,
            artist: state.artist,
            albumName: state.albumName,
            durationHint: state.durationHint
        )
        updateNowPlayingMetadata(force: true)
#if os(iOS)
        loadNowPlayingArtwork(
            for: state.mediaID,
            title: state.title,
            artist: state.artist,
            fallbackURL: state.artworkURL
        )
#endif
    }

    // MARK: - Loaders

    public func load(external track: ExternalQueueTrack, preserveQueue: Bool = false) {
        loadExternalTrack(track, preserveQueue: preserveQueue)
    }

    public func load(song: YouTubeMusicSong, preserveQueue: Bool = false) {
        loadMusicTrack(
            mediaID: song.videoId,
            title: song.title,
            artist: song.artistsDisplay,
            albumName: song.album,
            thumbnailURL: song.thumbnailURL,
            explicit: song.isExplicit,
            durationHint: Self.lyricsDurationHint(from: song.duration),
            preserveQueue: preserveQueue
        )

        if !preserveQueue {
            seedRadioQueue(from: song)
        }
    }

    public func load(video: YouTubeVideo, preserveQueue: Bool = false) {
        let targetMediaID = video.id

        let tapStartedAt = Date()
        let fallbackURL = normalizedArtworkURL(from: video.thumbnailURL)
        let displayTitle = normalizedMusicDisplayTitle(video.title, artist: video.author)
        let displayArtist = normalizedMusicDisplayArtist(video.author, title: video.title)

        let presentation = TrackPresentationState(
            mediaID: targetMediaID,
            title: displayTitle,
            artist: displayArtist,
            albumName: nil,
            artworkURL: fallbackURL,
            isExplicit: false,
            streamingService: .youtube,
            qualityLabel: "Resolving...",
            codecLabel: "Resolving...",
            durationHint: Self.lyricsDurationHint(from: video.lengthInSeconds)
        )
        preparePlaybackSession(for: presentation, preserveQueue: preserveQueue)

        currentLoadTask?.cancel()
        currentLoadTask = Task {
            if Task.isCancelled { return }

            do {
                let candidates = try await self.resolvePlaybackCandidates(forID: video.id)

                if Task.isCancelled { return }
                guard self.currentVideoId == targetMediaID else { return }

                self.configurePlaybackCandidates(for: video.id, candidates: candidates)
                self.playCurrentPlaybackCandidate()
                self.startArtworkVideoProcessingIfNeeded(
                    for: video.id,
                    title: displayTitle,
                    artist: displayArtist,
                    albumName: nil
                )
                self.logPlayback("Started playback for video id=\(video.id)")

                if !preserveQueue {
                    self.seedRadioQueueForVideoTrack(
                        video: video,
                        expectedCurrentMediaID: targetMediaID
                    )
                }

                self.preloadNextQueueEntryIfNeeded()

                if settings.metricsEnabled {
                    let elapsed = Date().timeIntervalSince(tapStartedAt) * 1000
                    await self.playbackMetricsStore.recordTapToPlay(durationMs: elapsed)
                }
            } catch {
                if error is CancellationError { return }
                guard self.currentVideoId == targetMediaID else { return }
                self.handlePlaybackFailure(error)
            }
        }
    }

    private func loadMusicTrack(
        mediaID: String,
        title: String,
        artist: String,
        albumName: String?,
        thumbnailURL: URL?,
        explicit: Bool,
        durationHint: Int?,
        preserveQueue: Bool
    ) {
        let targetMediaID = mediaID

        let tapStartedAt = Date()
        let displayTitle = normalizedMusicDisplayTitle(title, artist: artist)
        let displayArtist = normalizedMusicDisplayArtist(artist, title: title)

        let presentation = TrackPresentationState(
            mediaID: mediaID,
            title: displayTitle,
            artist: displayArtist,
            albumName: albumName,
            artworkURL: thumbnailURL,
            isExplicit: explicit,
            streamingService: .youtube,
            qualityLabel: "Resolving...",
            codecLabel: "Resolving...",
            durationHint: durationHint
        )
        preparePlaybackSession(for: presentation, preserveQueue: preserveQueue)

        currentLoadTask?.cancel()
        currentLoadTask = Task {
            if Task.isCancelled { return }

            do {
                // Resolve YouTube candidates and start playback immediately.
                let youtubeCandidates = try await self.resolvePlaybackCandidates(forID: mediaID)

                if Task.isCancelled { return }
                guard self.currentVideoId == targetMediaID else { return }

                self.configurePlaybackCandidates(for: mediaID, candidates: youtubeCandidates)
                self.playCurrentPlaybackCandidate()
                self.startArtworkVideoProcessingIfNeeded(
                    for: mediaID,
                    title: self.currentTitle,
                    artist: self.currentArtist,
                    albumName: albumName
                )
                self.logPlayback("Started playback for song id=\(mediaID)")
                self.preloadNextQueueEntryIfNeeded()

                if settings.metricsEnabled {
                    let elapsed = Date().timeIntervalSince(tapStartedAt) * 1000
                    await self.playbackMetricsStore.recordTapToPlay(durationMs: elapsed)
                }

            } catch {
                if error is CancellationError { return }
                guard self.currentVideoId == targetMediaID else { return }
                self.handlePlaybackFailure(error)
            }
        }
    }


    public func loadExternalStream(
        mediaID: String,
        streamURL: URL,
        title: String,
        artist: String,
        artworkURL: URL?,
        service: FederatedService,
        qualityLabel: String,
        codecLabel: String
    ) {
        let immediateTrack = ExternalQueueTrack(
            mediaID: mediaID,
            title: title,
            artist: artist,
            artworkURL: artworkURL,
            service: service,
            isExplicit: false,
            qualityLabelHint: qualityLabel,
            codecLabelHint: codecLabel,
            resolvePayload: {
                ExternalStreamPayload(
                    mediaID: mediaID,
                    streamURL: streamURL,
                    title: title,
                    artist: artist,
                    artworkURL: artworkURL,
                    service: service,
                    qualityLabel: qualityLabel,
                    codecLabel: codecLabel
                )
            }
        )

        loadExternalTrack(immediateTrack, preserveQueue: false)
    }

    // MARK: - Controls

    public func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    public func skipToNext() {
        advanceToNextQueueEntry(triggeredByPlaybackEnd: false)
    }

    public func skipToPrevious() {
        guard currentVideoId != nil else {
            updateRemoteCommandState()
            return
        }

        if currentTime > 5 {
            seek(to: 0)
            return
        }

        guard hasPreviousTrackInQueue, let queuePosition else {
            seek(to: 0)
            return
        }

        let previousIndex = queuePosition - 1
        self.queuePosition = previousIndex
        stopCurrentPlaybackForImmediateTransition()
        load(entry: playbackQueue[previousIndex])
        preloadNextQueueEntryIfNeeded()
    }

    private func advanceToNextQueueEntry(triggeredByPlaybackEnd: Bool) {
        guard hasNextTrackInQueue, let queuePosition else {
            playbackEngine.setIsPlaying(false)
            updateNowPlayingPlaybackInfo(force: true)
            updateRemoteCommandState()
            return
        }

        let nextIndex = queuePosition + 1
        guard playbackQueue.indices.contains(nextIndex) else {
            updateRemoteCommandState()
            return
        }

        let nextEntry = playbackQueue[nextIndex]
        self.queuePosition = nextIndex

        if let prepared = preparedNextPlayback, prepared.mediaID == nextEntry.mediaID {
            preparedNextPlayback = nil
            if shouldRefreshPreparedPlaybackBeforeUse(prepared) {
                if !triggeredByPlaybackEnd {
                    stopCurrentPlaybackForImmediateTransition()
                }
                load(entry: nextEntry)
            } else {
                playPreparedQueueEntry(prepared)
            }
        } else {
            if !triggeredByPlaybackEnd {
                stopCurrentPlaybackForImmediateTransition()
            }
            load(entry: nextEntry)
        }

        scheduleRadioContinuationIfNeeded()
        preloadNextQueueEntryIfNeeded()
    }

    private func stopCurrentPlaybackForImmediateTransition() {
        currentLoadTask?.cancel()
        player.pause()
        player.replaceCurrentItem(with: nil)
        removeCurrentItemEndObserver()
        playbackEngine.setIsPlaying(false)
        playbackEngine.resetProgress()
        updateNowPlayingPlaybackInfo(force: true)
        updateRemoteCommandState()
    }

    public func seek(to seconds: Double) {
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: time) { [weak self] _ in
            Task { @MainActor in
                self?.updateNowPlayingPlaybackInfo(force: true)
            }
        }
    }

    /// Reload the current video with current playback configuration.
    public func reloadCurrentVideo() {
        guard let id = currentVideoId else { return }
        let targetMediaID = id
        resetPlaybackCandidates(for: id)
        currentLoadTask?.cancel()
        currentLoadTask = Task {
            if Task.isCancelled { return }
            do {
                let candidates = try await self.resolvePlaybackCandidates(forID: id)

                if Task.isCancelled { return }
                guard self.currentVideoId == targetMediaID else { return }

                self.configurePlaybackCandidates(for: id, candidates: candidates)
                self.playCurrentPlaybackCandidate()
                self.startArtworkVideoProcessingIfNeeded(
                    for: id,
                    title: currentTitle,
                    artist: currentArtist,
                    albumName: currentAlbumNameHint
                )
            } catch {
                if error is CancellationError { return }
                guard self.currentVideoId == targetMediaID else { return }
                self.playbackError = error.localizedDescription
            }
        }
    }

    #if os(iOS)
    public func handleScenePhaseChange(_ phase: ScenePhase) {
        VolumeButtonSkipController.shared.handleScenePhaseChange(phase)
        guard isPlaying else { return }
        switch phase {
        case .active, .background:
            reactivateAudioSessionIfNeeded()
        case .inactive:
            break
        @unknown default:
            break
        }
    }
    #endif

    private func load(entry: PlaybackQueueEntry) {
        switch entry {
        case .song(let song):
            load(song: song, preserveQueue: true)
        case .video(let video):
            load(video: video, preserveQueue: true)
        case .cachedRadio(let track):
            loadMusicTrack(
                mediaID: track.videoID,
                title: track.title,
                artist: track.artist,
                albumName: track.albumName,
                thumbnailURL: track.thumbnailURL,
                explicit: track.isExplicit,
                durationHint: nil,
                preserveQueue: true
            )
        case .external(let track):
            load(external: track, preserveQueue: true)
        }
    }

    private func loadExternalTrack(_ track: ExternalQueueTrack, preserveQueue: Bool) {
        let normalizedMediaID = track.mediaID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedMediaID.isEmpty else {
            playbackError = "Invalid media identifier for external stream."
            return
        }

        let tapStartedAt = Date()

        let displayTitle = normalizedMusicDisplayTitle(track.title, artist: track.artist)
        let displayArtist = normalizedMusicDisplayArtist(track.artist, title: track.title)
        let initialPresentation = TrackPresentationState(
            mediaID: normalizedMediaID,
            title: displayTitle,
            artist: displayArtist,
            albumName: nil,
            artworkURL: track.artworkURL,
            isExplicit: track.isExplicit,
            streamingService: Self.streamingService(for: track.service),
            qualityLabel: track.qualityLabelHint ?? "Resolving...",
            codecLabel: track.codecLabelHint ?? "Resolving...",
            durationHint: nil
        )

        currentLoadTask?.cancel()
        preparePlaybackSession(for: initialPresentation, preserveQueue: preserveQueue)

        currentLoadTask = Task {
            if Task.isCancelled { return }

            do {
                let payload: ExternalStreamPayload
                if let cachedPayload = self.externalPayloadCache[normalizedMediaID] {
                    payload = cachedPayload
                } else {
                    payload = try await track.resolvePayload()
                    self.externalPayloadCache[normalizedMediaID] = payload
                }

                if Task.isCancelled { return }
                guard self.currentVideoId == normalizedMediaID else { return }

                self.currentTitle = normalizedMusicDisplayTitle(payload.title, artist: payload.artist)
                self.currentArtist = normalizedMusicDisplayArtist(payload.artist, title: payload.title)
                self.currentImageURL = payload.artworkURL ?? track.artworkURL
                self.currentStreamingServiceName = payload.service.rawValue
                self.currentAudioQualityLabel = payload.qualityLabel
                self.currentAudioCodecLabel = payload.codecLabel
                self.pendingPlaybackFormatOverride = (payload.qualityLabel, payload.codecLabel)

                let candidate = PlaybackCandidate(
                    url: payload.streamURL,
                    streamKind: .audio,
                    mimeType: self.mimeTypeForCodecLabel(payload.codecLabel),
                    itag: nil,
                    expiresAt: nil,
                    isCompatible: true
                )

                self.configurePlaybackCandidates(for: normalizedMediaID, candidates: [candidate])
                self.playCurrentPlaybackCandidate()
                self.startArtworkVideoProcessingIfNeeded(
                    for: normalizedMediaID,
                    title: self.currentTitle,
                    artist: self.currentArtist,
                    albumName: nil
                )
                self.updateNowPlayingMetadata(force: true)

                if !preserveQueue {
                    self.seedRadioQueueForExternalTrack(
                        externalTrack: track,
                        resolvedPayload: payload,
                        expectedCurrentMediaID: normalizedMediaID
                    )
                }

                self.preloadNextQueueEntryIfNeeded()

#if os(iOS)
                self.loadNowPlayingArtwork(
                    for: normalizedMediaID,
                    title: self.currentTitle,
                    artist: self.currentArtist,
                    fallbackURL: self.currentImageURL
                )
#endif

                if self.settings.metricsEnabled {
                    let elapsed = Date().timeIntervalSince(tapStartedAt) * 1000
                    await self.playbackMetricsStore.recordTapToPlay(durationMs: elapsed)
                }
            } catch {
                if error is CancellationError { return }
                guard self.currentVideoId == normalizedMediaID else { return }
                self.handlePlaybackFailure(error)
            }
        }
    }

    private func clearQueueContext() {
        clearRadioAutoplayState()
        resetHiResAvailabilityState()
        playbackRecoveryTask?.cancel()
        playbackRecoveryTask = nil
        playbackRecoveryAttemptCounts.removeAll(keepingCapacity: true)
        nextPlaybackPreloadTask?.cancel()
        nextPlaybackPreloadTask = nil
        preparedNextPlayback = nil
        externalPayloadCache.removeAll(keepingCapacity: true)
        playbackQueue = []
        queuePosition = nil
        queueCount = 0
        queueSource = .detached
        updateRemoteCommandState()
    }

    private func seedRadioQueue(from seedSong: YouTubeMusicSong) {
        let seedVideoID = seedSong.videoId
        radioSeedVideoID = seedVideoID
        radioAutoplayTask?.cancel()

        radioAutoplayTask = Task { @MainActor [weak self] in
            guard let self else { return }

            let cachedSession = self.radioSessionStore.session(forSeedVideoID: seedVideoID)

            if let cachedSession,
               self.shouldReuseCachedRadioSession(cachedSession),
               self.currentVideoId == seedVideoID {
                self.applyCachedRadioSession(cachedSession, fallbackSeed: seedSong)
                self.scheduleRadioContinuationIfNeeded()
                return
            }

            do {
                let radio = try await self.youtube.music.getRadio(videoId: seedVideoID)
                guard !Task.isCancelled, self.currentVideoId == seedVideoID else { return }

                self.radioPlaylistID = radio.playlistId
                self.radioContinuationToken = radio.continuationToken

                var tracks = self.buildSeededRadioTracks(seedSong: seedSong, radioItems: radio.items)
                tracks = await self.hydrateSeedRadioTracksIfNeeded(tracks, playlistID: self.radioPlaylistID)
                guard !Task.isCancelled, self.currentVideoId == seedVideoID else { return }

                self.applyRadioTracksToQueue(tracks, seedVideoID: seedVideoID)
                self.scheduleRadioContinuationIfNeeded()
            } catch {
                guard !Task.isCancelled else { return }
                if let cachedSession,
                   self.currentVideoId == seedVideoID,
                   !cachedSession.tracks.isEmpty {
                    self.applyCachedRadioSession(cachedSession, fallbackSeed: seedSong)
                    self.scheduleRadioContinuationIfNeeded()
                }
                self.logPlayback("Radio seed failed for id=\(seedVideoID): \(error.localizedDescription)")
            }
        }
    }

    private func seedRadioQueueForExternalTrack(
        externalTrack: ExternalQueueTrack,
        resolvedPayload: ExternalStreamPayload,
        expectedCurrentMediaID: String
    ) {

        let title = normalizedMusicDisplayTitle(resolvedPayload.title, artist: resolvedPayload.artist)
        let artist = normalizedMusicDisplayArtist(resolvedPayload.artist, title: resolvedPayload.title)
        let query = radioSeedQuery(title: title, artist: artist)
        guard !query.isEmpty else { return }

        radioAutoplayTask?.cancel()
        radioAutoplayTask = Task { @MainActor [weak self] in
            guard let self else { return }
            guard self.currentVideoId == expectedCurrentMediaID else { return }

            do {
                let searchResults = try await self.youtube.music.search(query)
                guard !Task.isCancelled,
                      self.currentVideoId == expectedCurrentMediaID,
                      let seedSong = self.bestRadioSeedSong(
                        from: searchResults,
                        title: title,
                        artist: artist
                      ) else {
                    return
                }

                let seedVideoID = seedSong.videoId
                self.radioSeedVideoID = seedVideoID
                let leadingEntry = PlaybackQueueEntry.external(externalTrack)
                let cachedSession = self.radioSessionStore.session(forSeedVideoID: seedVideoID)

                if let cachedSession,
                   self.shouldReuseCachedRadioSession(cachedSession),
                   self.currentVideoId == expectedCurrentMediaID {
                    self.applyCachedRadioSession(
                        cachedSession,
                        fallbackSeed: seedSong,
                        leadingEntry: leadingEntry,
                        currentMediaID: expectedCurrentMediaID
                    )
                    self.scheduleRadioContinuationIfNeeded()
                    return
                }

                let radio = try await self.youtube.music.getRadio(videoId: seedVideoID)
                guard !Task.isCancelled, self.currentVideoId == expectedCurrentMediaID else { return }

                self.radioPlaylistID = radio.playlistId
                self.radioContinuationToken = radio.continuationToken

                var tracks = self.buildSeededRadioTracks(seedSong: seedSong, radioItems: radio.items)
                tracks = await self.hydrateSeedRadioTracksIfNeeded(tracks, playlistID: self.radioPlaylistID)
                guard !Task.isCancelled, self.currentVideoId == expectedCurrentMediaID else { return }

                self.applyRadioTracksToQueue(
                    tracks,
                    seedVideoID: seedVideoID,
                    leadingEntry: leadingEntry,
                    currentMediaID: expectedCurrentMediaID
                )
                self.scheduleRadioContinuationIfNeeded()
            } catch {
                guard !Task.isCancelled else { return }
                self.logPlayback("External radio seed failed for query=\(query): \(error.localizedDescription)")
            }
        }
    }

    private func seedRadioQueueForVideoTrack(
        video: YouTubeVideo,
        expectedCurrentMediaID: String
    ) {
        let displayTitle = normalizedMusicDisplayTitle(video.title, artist: video.author)
        let displayArtist = normalizedMusicDisplayArtist(video.author, title: video.title)
        let query = radioSeedQuery(title: displayTitle, artist: displayArtist)
        let leadingEntry = PlaybackQueueEntry.video(video)

        radioAutoplayTask?.cancel()
        radioAutoplayTask = Task { @MainActor [weak self] in
            guard let self else { return }
            guard self.currentVideoId == expectedCurrentMediaID else { return }

            do {
                let directRadio = try await self.youtube.music.getRadio(videoId: video.id)
                guard !Task.isCancelled,
                      self.currentVideoId == expectedCurrentMediaID else {
                    return
                }

                var directTracks = self.buildRadioTracks(from: directRadio.items)
                if !directTracks.isEmpty {
                    self.radioSeedVideoID = video.id
                    self.radioPlaylistID = directRadio.playlistId
                    self.radioContinuationToken = directRadio.continuationToken

                    directTracks = await self.hydrateSeedRadioTracksIfNeeded(
                        directTracks,
                        playlistID: self.radioPlaylistID
                    )
                    guard !Task.isCancelled,
                          self.currentVideoId == expectedCurrentMediaID else {
                        return
                    }

                    self.applyRadioTracksToQueue(
                        directTracks,
                        seedVideoID: video.id,
                        leadingEntry: leadingEntry,
                        currentMediaID: expectedCurrentMediaID
                    )
                    self.scheduleRadioContinuationIfNeeded()
                    return
                }
            } catch {
                self.logPlayback("Video direct radio seed failed for id=\(video.id): \(error.localizedDescription)")
            }

            guard !query.isEmpty else { return }

            do {
                let searchResults = try await self.youtube.music.search(query)
                guard !Task.isCancelled,
                      self.currentVideoId == expectedCurrentMediaID,
                      let seedSong = self.bestRadioSeedSong(
                        from: searchResults,
                        title: displayTitle,
                        artist: displayArtist
                      ) else {
                    return
                }

                let seedVideoID = seedSong.videoId
                self.radioSeedVideoID = seedVideoID
                let cachedSession = self.radioSessionStore.session(forSeedVideoID: seedVideoID)

                if let cachedSession,
                   self.shouldReuseCachedRadioSession(cachedSession),
                   self.currentVideoId == expectedCurrentMediaID {
                    self.applyCachedRadioSession(
                        cachedSession,
                        fallbackSeed: seedSong,
                        leadingEntry: leadingEntry,
                        currentMediaID: expectedCurrentMediaID
                    )
                    self.scheduleRadioContinuationIfNeeded()
                    return
                }

                let radio = try await self.youtube.music.getRadio(videoId: seedVideoID)
                guard !Task.isCancelled,
                      self.currentVideoId == expectedCurrentMediaID else {
                    return
                }

                self.radioPlaylistID = radio.playlistId
                self.radioContinuationToken = radio.continuationToken

                var tracks = self.buildSeededRadioTracks(seedSong: seedSong, radioItems: radio.items)
                tracks = await self.hydrateSeedRadioTracksIfNeeded(tracks, playlistID: self.radioPlaylistID)
                guard !Task.isCancelled,
                      self.currentVideoId == expectedCurrentMediaID else {
                    return
                }

                self.applyRadioTracksToQueue(
                    tracks,
                    seedVideoID: seedVideoID,
                    leadingEntry: leadingEntry,
                    currentMediaID: expectedCurrentMediaID
                )
                self.scheduleRadioContinuationIfNeeded()
            } catch {
                guard !Task.isCancelled else { return }
                self.logPlayback("Video metadata radio seed failed for query=\(query): \(error.localizedDescription)")
            }
        }
    }

    private func radioSeedQuery(title: String, artist: String) -> String {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)

        if !normalizedTitle.isEmpty && !normalizedArtist.isEmpty {
            return "\(normalizedTitle) \(normalizedArtist)"
        }
        if !normalizedTitle.isEmpty {
            return normalizedTitle
        }
        return normalizedArtist
    }

    private func bestRadioSeedSong(from candidates: [YouTubeMusicSong], title: String, artist: String) -> YouTubeMusicSong? {
        guard !candidates.isEmpty else { return nil }

        let targetTitle = title.lowercased()
        let targetArtist = artist.lowercased()

        return candidates.max { lhs, rhs in
            let lhsTitle = normalizedMusicDisplayTitle(lhs.title, artist: lhs.artistsDisplay).lowercased()
            let rhsTitle = normalizedMusicDisplayTitle(rhs.title, artist: rhs.artistsDisplay).lowercased()
            let lhsArtist = normalizedMusicDisplayArtist(lhs.artistsDisplay, title: lhs.title).lowercased()
            let rhsArtist = normalizedMusicDisplayArtist(rhs.artistsDisplay, title: rhs.title).lowercased()

            let lhsScore = (0.7 * tokenOverlapScore(lhsTitle, targetTitle)) + (0.3 * tokenOverlapScore(lhsArtist, targetArtist))
            let rhsScore = (0.7 * tokenOverlapScore(rhsTitle, targetTitle)) + (0.3 * tokenOverlapScore(rhsArtist, targetArtist))
            return lhsScore < rhsScore
        }
    }

    private func shouldReuseCachedRadioSession(_ session: RadioSessionStore.Session) -> Bool {
        let validTrackCount = session.tracks.compactMap { CachedRadioTrack(cached: $0) }.count
        if validTrackCount == 0 {
            return false
        }
        return validTrackCount >= RadioAutoplayPolicy.minCachedTracksWithoutContinuation
    }

    private func hydrateSeedRadioTracksIfNeeded(
        _ tracks: [CachedRadioTrack],
        playlistID: String?
    ) async -> [CachedRadioTrack] {
        guard tracks.count < RadioAutoplayPolicy.minSeedTracksBeforePlaylistHydration else {
            return tracks
        }

        guard let playlistID = playlistID?.trimmingCharacters(in: .whitespacesAndNewlines),
              !playlistID.isEmpty else {
            return tracks
        }

        do {
            let queueItems = try await youtube.music.getQueue(playlistId: playlistID)
            guard !queueItems.isEmpty else { return tracks }

            var merged = tracks
            var knownIDs = Set(merged.map(\.videoID))
            for song in queueItems {
                let track = CachedRadioTrack(song: song)
                guard knownIDs.insert(track.videoID).inserted else { continue }
                merged.append(track)
                if merged.count >= RadioAutoplayPolicy.maxSeedQueueTracks {
                    break
                }
            }

            if merged.count > tracks.count {
                logPlayback("Radio seed hydrated from playlist: +\(merged.count - tracks.count) track(s)")
            }

            return merged
        } catch {
            logPlayback("Radio seed hydration failed for playlistID=\(playlistID): \(error.localizedDescription)")
            return tracks
        }
    }

    private func clearRadioAutoplayState() {
        radioAutoplayTask?.cancel()
        radioAutoplayTask = nil
        radioContinuationTask?.cancel()
        radioContinuationTask = nil
        radioSeedVideoID = nil
        radioPlaylistID = nil
        radioContinuationToken = nil
        isLoadingRadioContinuation = false
    }

    private func applyCachedRadioSession(
        _ session: RadioSessionStore.Session,
        fallbackSeed: YouTubeMusicSong,
        leadingEntry: PlaybackQueueEntry? = nil,
        currentMediaID: String? = nil
    ) {
        var tracks = session.tracks.compactMap { CachedRadioTrack(cached: $0) }
        let seedTrack = CachedRadioTrack(song: fallbackSeed)

        if !tracks.contains(where: { $0.videoID == seedTrack.videoID }) {
            tracks.insert(seedTrack, at: 0)
        }

        radioPlaylistID = session.playlistID
        radioContinuationToken = session.continuationToken
        applyRadioTracksToQueue(
            Array(tracks.prefix(RadioAutoplayPolicy.maxSeedQueueTracks)),
            seedVideoID: seedTrack.videoID,
            leadingEntry: leadingEntry,
            currentMediaID: currentMediaID
        )
    }

    private func buildSeededRadioTracks(seedSong: YouTubeMusicSong, radioItems: [YouTubeMusicSong]) -> [CachedRadioTrack] {
        var allSongs = [seedSong]
        allSongs.append(contentsOf: radioItems)
        
        // Deduplicate by videoId then by fingerprint
        let uniqueTracks = allSongs.removeDuplicates()
                                   .removeDuplicates(on: { "\($0.title.lowercased())|\($0.artistsDisplay.lowercased())" })
                                   .map(CachedRadioTrack.init(song:))
        
        return Array(uniqueTracks.prefix(RadioAutoplayPolicy.maxSeedQueueTracks))
    }

    private func buildRadioTracks(from radioItems: [YouTubeMusicSong]) -> [CachedRadioTrack] {
        let uniqueTracks = radioItems.removeDuplicates()
                                     .removeDuplicates(on: { "\($0.title.lowercased())|\($0.artistsDisplay.lowercased())" })
                                     .map(CachedRadioTrack.init(song:))
        return Array(uniqueTracks.prefix(RadioAutoplayPolicy.maxSeedQueueTracks))
    }

    private func applyRadioTracksToQueue(
        _ tracks: [CachedRadioTrack],
        seedVideoID: String,
        leadingEntry: PlaybackQueueEntry? = nil,
        currentMediaID: String? = nil
    ) {
        guard !tracks.isEmpty else { return }

        var entries = tracks.map { PlaybackQueueEntry.cachedRadio($0) }
        if let leadingEntry {
            entries.removeAll { $0.mediaID == leadingEntry.mediaID }
            entries.insert(leadingEntry, at: 0)
        }

        playbackQueue = entries
        queueCount = entries.count
        queueSource = .radioAutoplay

        let playbackMediaID = currentMediaID ?? currentVideoId
        if let playbackMediaID {
            queuePosition = entries.firstIndex(where: { $0.mediaID == playbackMediaID }) ?? 0
        } else {
            queuePosition = 0
        }

        if radioSeedVideoID == nil {
            radioSeedVideoID = seedVideoID
        }

        persistCurrentRadioSession()
        updateRemoteCommandState()
        preloadNextQueueEntryIfNeeded()
    }

    private func scheduleRadioContinuationIfNeeded() {
        guard queueSource == .radioAutoplay,
              let queuePosition,
              !isLoadingRadioContinuation,
              let continuation = radioContinuationToken,
              !continuation.isEmpty else {
            return
        }

        let remainingItems = playbackQueue.count - queuePosition - 1
        guard remainingItems <= RadioAutoplayPolicy.queueLowWatermark else {
            return
        }

        isLoadingRadioContinuation = true
        radioContinuationTask?.cancel()
        radioContinuationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.isLoadingRadioContinuation = false
            }

            do {
                let previousToken = self.radioContinuationToken
                let page = try await self.youtube.music.getRadioContinuation(token: continuation)
                guard !Task.isCancelled,
                      self.queueSource == .radioAutoplay else {
                    return
                }

                self.radioContinuationToken = page.continuationToken
                if let playlistID = page.playlistId, !playlistID.isEmpty {
                    self.radioPlaylistID = playlistID
                }

                let appended = self.appendRadioTracks(page.items.removeDuplicates().map(CachedRadioTrack.init(song:)))
                if appended == 0 {
                    let tokenChanged = previousToken != self.radioContinuationToken
                    if !tokenChanged {
                        await self.backfillRadioTracksFromPlaylistIfNeeded()
                    }
                }
            } catch {
                guard !Task.isCancelled else { return }
                await self.backfillRadioTracksFromPlaylistIfNeeded()
                self.logPlayback("Radio continuation failed: \(error.localizedDescription)")
            }
        }
    }

    @discardableResult
    private func appendRadioTracks(_ incoming: [CachedRadioTrack]) -> Int {
        guard !incoming.isEmpty else { return 0 }

        var knownIDs = Set(playbackQueue.map(\.mediaID))
        var knownFingerprints = Set(playbackQueue.map(\.fingerprint))
        
        var appended: [PlaybackQueueEntry] = []
        for track in incoming {
            guard knownIDs.insert(track.videoID).inserted else { continue }
            guard knownFingerprints.insert(track.fingerprint).inserted else { continue }
            
            appended.append(.cachedRadio(track))
        }

        guard !appended.isEmpty else { return 0 }

        playbackQueue.append(contentsOf: appended)
        queueCount = playbackQueue.count
        persistCurrentRadioSession()
        updateRemoteCommandState()
        preloadNextQueueEntryIfNeeded()
        return appended.count
    }

    private func backfillRadioTracksFromPlaylistIfNeeded() async {
        guard queueSource == .radioAutoplay,
              let playlistID = radioPlaylistID?.trimmingCharacters(in: .whitespacesAndNewlines),
              !playlistID.isEmpty else {
            return
        }

        do {
            let queueItems = try await youtube.music.getQueue(playlistId: playlistID)
            guard !queueItems.isEmpty else { return }

            let appended = appendRadioTracks(queueItems.removeDuplicates().map(CachedRadioTrack.init(song:)))
            if appended > 0 {
                logPlayback("Radio playlist backfill appended \(appended) track(s)")
            }
        } catch {
            logPlayback("Radio playlist backfill failed for playlistID=\(playlistID): \(error.localizedDescription)")
        }
    }

    private func persistCurrentRadioSession() {
        guard queueSource == .radioAutoplay,
              let seedVideoID = radioSeedVideoID else {
            return
        }

        let tracks = playbackQueue.compactMap { entry -> CachedRadioTrack? in
            switch entry {
            case .cachedRadio(let track):
                return track
            case .song(let song):
                return CachedRadioTrack(song: song)
            case .video:
                return nil
            case .external:
                return nil
            }
        }

        guard !tracks.isEmpty else { return }

        radioSessionStore.save(
            session: RadioSessionStore.Session(
                seedVideoID: seedVideoID,
                playlistID: radioPlaylistID,
                continuationToken: radioContinuationToken,
                tracks: tracks.map(\.persisted),
                updatedAt: .now
            )
        )
    }

    private func shouldRefreshPreparedPlaybackBeforeUse(_ prepared: PreparedQueuePlayback) -> Bool {
        guard prepared.streamingService == .youtube || prepared.streamingService == .youtubeMusic else {
            return false
        }

        if Date().timeIntervalSince(prepared.preparedAt) >= CachePolicy.preparedYouTubeMaxAge {
            return true
        }

        if prepared.playbackCandidates.contains(where: { $0.expiresAt == nil }) {
            return true
        }

        if let earliestExpiry = prepared.playbackCandidates.compactMap(\.expiresAt).min(),
           earliestExpiry.timeIntervalSinceNow <= CachePolicy.playbackMinimumRemainingLifetime {
            return true
        }

        return false
    }

    private func playPreparedQueueEntry(_ prepared: PreparedQueuePlayback) {
        currentLoadTask?.cancel()

        let presentation = TrackPresentationState(
            mediaID: prepared.mediaID,
            title: prepared.title,
            artist: prepared.artist,
            albumName: prepared.albumName,
            artworkURL: prepared.artworkURL,
            isExplicit: prepared.isExplicit,
            streamingService: prepared.streamingService,
            qualityLabel: prepared.qualityLabel,
            codecLabel: prepared.codecLabel,
            durationHint: prepared.durationHint
        )
        preparePlaybackSession(for: presentation, preserveQueue: true)

        if prepared.playbackCandidates.isEmpty {
            resetPlaybackCandidates(for: prepared.mediaID)
        } else {
            configurePlaybackCandidates(for: prepared.mediaID, candidates: prepared.playbackCandidates)
        }

        observeCurrentItemStatus(prepared.item)
        observeCurrentItemEnd(prepared.item)
        player.replaceCurrentItem(with: prepared.item)

#if os(iOS)
        if #available(iOS 14.0, *) {
            player.audiovisualBackgroundPlaybackPolicy = .continuesIfPossible
        }
#endif

        player.seek(to: .zero)
        playbackEngine.play()

        startArtworkVideoProcessingIfNeeded(
            for: prepared.mediaID,
            title: prepared.title,
            artist: prepared.artist,
            albumName: prepared.albumName
        )

        updateRemoteCommandState()
        preloadNextQueueEntryIfNeeded()
    }

    public func checkForHiResVersion() async {
        guard !isCheckingHiResAvailability else {
            return
        }

        guard let currentMediaID = currentVideoId else {
            return
        }

        guard !currentMediaID.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty else {
            return
        }

        let title = normalizedMusicDisplayTitle(currentTitle, artist: currentArtist)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, title != "Not Playing" else {
            return
        }

        isCheckingHiResAvailability = true
        pendingHiResPayload = nil
        hiResAvailabilityMessage = nil
        isCheckingHiResAvailability = false
    }

    public func switchToHiResVersionIfAvailable() {
        guard let payload = pendingHiResPayload else { return }

        loadExternalStream(
            mediaID: payload.mediaID,
            streamURL: payload.streamURL,
            title: payload.title,
            artist: payload.artist,
            artworkURL: payload.artworkURL,
            service: payload.service,
            qualityLabel: payload.qualityLabel,
            codecLabel: payload.codecLabel
        )

        pendingHiResPayload = nil
        hiResAvailabilityMessage = nil
    }

    private func resetHiResAvailabilityState() {
        pendingHiResPayload = nil
        hiResAvailabilityMessage = nil
        isCheckingHiResAvailability = false
    }

    func playbackLabels(for candidate: PlaybackCandidate) -> (quality: String, codec: String) {
        let qualityLabel: String
        switch candidate.streamKind {
        case .hls:
            qualityLabel = "Adaptive"
        case .muxed:
            qualityLabel = "Muxed"
        case .audio:
            qualityLabel = "Direct Audio"
        }

        let codecLabel = codecLabel(for: candidate)
        return (qualityLabel, codecLabel)
    }

    private func codecLabel(for candidate: PlaybackCandidate) -> String {
        let mime = candidate.mimeType?.lowercased() ?? ""
        if mime.contains("flac") {
            return "FLAC"
        }
        if mime.contains("aac") || mime.contains("mp4a") || mime.contains("m4a") {
            return "AAC"
        }
        if mime.contains("mpeg") || mime.contains("mp3") {
            return "MP3"
        }
        if mime.contains("opus") {
            return "Opus"
        }
        if candidate.streamKind == .hls {
            return "HLS"
        }
        return "Unknown"
    }

    static func streamingService(for federatedService: FederatedService) -> StreamingService {
        switch federatedService {
        case .youtube:
            return .youtube
        case .youtubeMusic:
            return .youtubeMusic
        case .spotify:
            return .spotify
        }
    }

    // MARK: - Playback Resolution

    private func resolvePlaybackEntry(forID id: String, forceDecipher: Bool = false) async throws -> VideoMetadataCache.Entry {
        // Capture sendable values (actor references and cookie string) up-front
        // so the @Sendable fetcher closure doesn't try to access MainActor
        // isolated properties directly.
        let youtube = self.youtube.main
        let normalizedID = canonicalPlaybackMediaID(id)

        // Use a fetcher that will attempt the InnerTube `/player` call first,
        // and if the server responds with `LOGIN_REQUIRED`, fall back to
        // extracting `ytInitialPlayerResponse` from the watch HTML (web client).
        return try await metadataCache.resolve(id: normalizedID, metricsEnabled: settings.metricsEnabled) { key in
            return try await youtube.video(id: key)
        }
    }

    func resolvePlaybackCandidates(forID id: String, forceDecipher: Bool = false) async throws -> [PlaybackCandidate] {
        let normalizedID = canonicalPlaybackMediaID(id)

        #if targetEnvironment(simulator)
        if supportsYouTubeCandidateRecovery {
            do {
                let youtube = self.youtube.main
                let androidVideo = try await youtube.videoAndroid(id: normalizedID)
                let androidCandidates = PlaybackCandidateBuilder.fromVideo(
                    androidVideo,
                    preferredURL: nil,
                    validUntil: Date().addingTimeInterval(3600)
                )

                if let preferredAndroidCandidate = androidCandidates.first {
                    logPlayback("Simulator Android fast path selected for id=\(normalizedID) kind=\(preferredAndroidCandidate.streamKind.rawValue)")
                    mediaCacheStore.savePlaybackResolution(
                        mediaID: normalizedID,
                        candidates: androidCandidates,
                        validUntil: Date().addingTimeInterval(3600)
                    )
                    return androidCandidates
                }
            } catch {
                logPlayback("Simulator Android fast path failed for id=\(normalizedID): \(error.localizedDescription)")
            }
        }
        #endif

        if !forceDecipher,
           let cachedCandidates = mediaCacheStore.playbackCandidates(
            for: normalizedID,
            maxAge: CachePolicy.playbackURLTTL
        ),
        !cachedCandidates.isEmpty {
            // ...
            let hasUnknownExpiryCandidate = cachedCandidates.contains(where: { $0.expiresAt == nil })
            if hasUnknownExpiryCandidate {
                logPlayback("Cached playback candidates missing expiry for id=\(normalizedID); invalidating for refresh")
                mediaCacheStore.invalidatePlayback(for: normalizedID)
            } else if let earliestExpiry = cachedCandidates.compactMap(\.expiresAt).min(),
                      earliestExpiry.timeIntervalSinceNow <= CachePolicy.playbackMinimumRemainingLifetime {
                logPlayback("Cached playback candidates near expiry for id=\(normalizedID); invalidating for refresh")
                mediaCacheStore.invalidatePlayback(for: normalizedID)
            } else {
                logPlayback("Using cached playback candidates for id=\(normalizedID)")
                return cachedCandidates
            }
        }

        // Fast path: if a resolver has a cached quick-play URL (warmed by Search prefetch),
        // use it immediately to start playback without waiting for the full video metadata.
        let resolver = await PlaybackURLResolver.sharedInstance()
        if !forceDecipher,
           let quickURL = await resolver.cachedURL(for: normalizedID) {
            let ext = quickURL.pathExtension.lowercased()
            let streamKind: PlaybackCandidate.StreamKind = ext == "m3u8" ? .hls : .muxed
            let mimeType: String? = {
                if streamKind == .hls { return "application/x-mpegURL" }
                if ext == "mp4" { return "audio/mp4" }
                if let components = URLComponents(url: quickURL, resolvingAgainstBaseURL: false),
                   let queryMime = components.queryItems?.first(where: { $0.name.caseInsensitiveCompare("mime") == .orderedSame })?.value,
                   !queryMime.isEmpty {
                    return queryMime
                }
                return nil
            }()
            let isCompatible = mimeType.map { !$0.lowercased().contains("webm") } ?? (streamKind == .hls || ext == "mp4")

            if isCompatible {
                let expiresAt = Date().addingTimeInterval(CachePolicy.playbackURLTTL)
                let candidate = PlaybackCandidate(url: quickURL, streamKind: streamKind, mimeType: mimeType, itag: nil, expiresAt: expiresAt, isCompatible: true)
                mediaCacheStore.savePlaybackResolution(mediaID: normalizedID, candidates: [candidate], validUntil: expiresAt)
                return [candidate]
            } else {
                logPlayback("Skipping cached quick URL for id=\(normalizedID) due to incompatible mime=\(mimeType ?? "unknown") host=\(quickURL.host ?? "unknown")")
            }
        }

        let entry = try await resolvePlaybackEntry(forID: normalizedID, forceDecipher: forceDecipher)
        let candidates = PlaybackCandidateBuilder.fromVideo(
            entry.video,
            preferredURL: entry.resolvedURL,
            validUntil: entry.validUntil
        )

        guard !candidates.isEmpty else {
            throw YouTubeError.decipheringFailed(videoId: normalizedID)
        }

        if currentStreamingServiceName == StreamingService.youtube.rawValue,
           !candidates.contains(where: { $0.streamKind == .hls || $0.streamKind == .muxed }) {
            do {
                let youtube = self.youtube.main
                let androidVideo = try await youtube.videoAndroid(id: normalizedID)
                let androidCandidates = PlaybackCandidateBuilder.fromVideo(
                    androidVideo,
                    preferredURL: nil,
                    validUntil: Date().addingTimeInterval(3600)
                )

                if !androidCandidates.isEmpty {
                    logPlayback("No iOS video-safe candidate for id=\(normalizedID); using Android direct-CDN fallback kind=\(androidCandidates[0].streamKind.rawValue)")
                    mediaCacheStore.savePlaybackResolution(
                        mediaID: normalizedID,
                        candidates: androidCandidates,
                        validUntil: Date().addingTimeInterval(3600)
                    )
                    return androidCandidates
                }
            } catch {
                logPlayback("Android fallback after iOS adaptive-only response failed for id=\(normalizedID): \(error.localizedDescription)")
            }
        }

        mediaCacheStore.savePlaybackResolution(
            mediaID: normalizedID,
            candidates: candidates,
            validUntil: entry.validUntil
        )

        return candidates
    }

    func resolvePrioritizedPlaybackCandidates(
        mediaID: String,
        title: String,
        artist: String
    ) async throws -> PrioritizedCandidateResolution {
        let youtubeCandidates = try await resolvePlaybackCandidates(forID: mediaID)
        return PrioritizedCandidateResolution(candidates: youtubeCandidates, hiResPayload: nil)
    }


    private func playFromBeginning(url: URL) {
        logPlayback("Creating playback item url=\(url.absoluteString) host=\(url.host ?? "unknown") service=\(currentStreamingServiceName)")
        let item = makePlayerItem(for: url)
        observeCurrentItemStatus(item)
        observeCurrentItemEnd(item)
        player.replaceCurrentItem(with: item)

        #if os(iOS)
        if #available(iOS 14.0, *) {
            player.audiovisualBackgroundPlaybackPolicy = .continuesIfPossible
        }
        #endif

        seek(to: .zero)
        playbackEngine.resetProgress()
        playbackEngine.play()

        updateNowPlayingMetadata()
        updateRemoteCommandState()
        preloadNextQueueEntryIfNeeded()
    }

    func makePlayerItem(for url: URL, service: StreamingService? = nil) -> AVPlayerItem {
        let resolvedService: StreamingService
        if let service {
            resolvedService = service
        } else {
            resolvedService = StreamingService(rawValue: currentStreamingServiceName) ?? .youtubeMusic
        }

        if resolvedService == .youtube || resolvedService == .youtubeMusic {
            logPlayback("Using direct AVPlayerItem load for YouTube host=\(url.host ?? "unknown")")
        } else {
            logPlayback("Using plain AVPlayerItem load host=\(url.host ?? "unknown")")
        }
        return AVPlayerItem(url: url)
    }

    func mimeTypeForCodecLabel(_ codecLabel: String) -> String? {
        let normalized = codecLabel.lowercased()
        if normalized.contains("flac") { return "audio/flac" }
        if normalized.contains("aac") { return "audio/aac" }
        if normalized.contains("mp3") { return "audio/mpeg" }
        if normalized.contains("hls") { return "application/x-mpegURL" }
        return nil
    }

    private func updateAudioFormatLabels(for candidate: PlaybackCandidate) {
        if let pendingPlaybackFormatOverride {
            currentAudioQualityLabel = pendingPlaybackFormatOverride.quality
            currentAudioCodecLabel = pendingPlaybackFormatOverride.codec
            self.pendingPlaybackFormatOverride = nil
            return
        }

        let labels = playbackLabels(for: candidate)
        currentAudioQualityLabel = labels.quality
        currentAudioCodecLabel = labels.codec
    }

    private func configurePlaybackCandidates(for mediaID: String, candidates: [PlaybackCandidate]) {
        playbackCandidatesMediaID = mediaID
        playbackCandidates = candidates
        playbackCandidateIndex = 0
        logPlayback("Prepared \(candidates.count) playback candidate(s) for id=\(mediaID)")
        let hostSummary = candidates
            .map { "\($0.streamKind.rawValue):\($0.url.host ?? "unknown-host")" }
            .joined(separator: " | ")
        logPlayback("Candidate hosts for id=\(mediaID): \(hostSummary)")
    }

    private func resetPlaybackCandidates(for mediaID: String) {
        playbackCandidatesMediaID = mediaID
        playbackCandidates = []
        playbackCandidateIndex = 0
    }

    private func resetPlaybackRecoveryState(for mediaID: String) {
        playbackRecoveryAttemptCounts.removeValue(forKey: mediaID)
    }

    private var supportsYouTubeCandidateRecovery: Bool {
        currentStreamingServiceName == StreamingService.youtube.rawValue
            || currentStreamingServiceName == StreamingService.youtubeMusic.rawValue
    }

    private func playCurrentPlaybackCandidate() {
        guard playbackCandidateIndex < playbackCandidates.count else {
            if let fallback = playbackCandidates.first {
                logPlayback("Playback candidate index out of range, retrying first candidate for id=\(playbackCandidatesMediaID ?? "unknown")")
                updateAudioFormatLabels(for: fallback)
                playFromBeginning(url: fallback.url)
            }
            return
        }

        let candidate = playbackCandidates[playbackCandidateIndex]
        logPlayback(
            "Trying playback candidate #\(playbackCandidateIndex + 1) kind=\(candidate.streamKind.rawValue) for id=\(playbackCandidatesMediaID ?? "unknown")"
        )
        updateAudioFormatLabels(for: candidate)
        playFromBeginning(url: candidate.url)
    }

    private func attemptNextPlaybackCandidateIfAvailable(errorMessage: String) -> Bool {
        guard let mediaID = currentVideoId,
              playbackCandidatesMediaID == mediaID,
              playbackCandidateIndex + 1 < playbackCandidates.count else {
            return false
        }

        playbackCandidateIndex += 1
        let candidate = playbackCandidates[playbackCandidateIndex]
        logPlayback(
            "Trying fallback playback candidate #\(playbackCandidateIndex + 1) kind=\(candidate.streamKind.rawValue) for id=\(mediaID) after error=\(errorMessage)"
        )
        updateAudioFormatLabels(for: candidate)
        playFromBeginning(url: candidate.url)
        return true
    }

    /// Re-fetches streaming data from the network (bypassing cache) when all local candidates fail.
    /// Mirrors SmartTubeIOS's exhaustiveRetry:
    /// 1. Try iOS client (via resolvePlaybackCandidates — fresh fetch, no cache)
    /// 2. Try Android client (muxed itag 18/22 — plays when iOS adaptive gets 403)
    /// 3. Try TV client (authenticated — plays age-restricted/auth-required videos)
    @MainActor
    private func exhaustiveRetry(for mediaID: String, originalError: Error?) async {
        guard !Task.isCancelled else { return }
        let normalizedMediaID = canonicalPlaybackMediaID(mediaID)
        print("🔁 PlayerViewModel: exhaustiveRetry starting for id=\(normalizedMediaID)")
        
        // 1. Thoroughly stop everything currently happening to avoid races during reset
        currentLoadTask?.cancel()
        currentLoadTask = nil
        
        // Cancel preloading and background tasks which might be "poisoning" the network/player context
        nextPlaybackPreloadTask?.cancel()
        nextPlaybackPreloadTask = nil
        preloadingNextMediaID = nil
        preparedNextPlayback = nil
        
        artworkVideoTask?.cancel()
        artworkVideoTask = nil
        
        radioAutoplayTask?.cancel()
        radioAutoplayTask = nil
        
        radioContinuationTask?.cancel()
        radioContinuationTask = nil
        
        #if os(iOS)
        accentLoadTask?.cancel()
        accentLoadTask = nil
        #endif
        
        lastFMScrobbleTask?.cancel()
        lastFMScrobbleTask = nil
        
        removeCurrentItemEndObserver()
        
        // 2. Hard reset the player engine to clear any "stuck" error states (e.g. NSURLErrorDomain code -1)
        playbackEngine.fullReset()

        // 3. Invalidate cached playback resolution so we get fresh URLs
        mediaCacheStore.invalidatePlayback(for: normalizedMediaID)

        // --- Attempt 1: iOS client (fresh fetch) ---
        do {
            let freshCandidates = try await resolvePlaybackCandidates(forID: normalizedMediaID, forceDecipher: true)
            guard !Task.isCancelled, currentVideoId == mediaID else { return }

            if !freshCandidates.isEmpty {
                print("✅ PlayerViewModel: exhaustiveRetry — got \(freshCandidates.count) iOS candidate(s) for id=\(normalizedMediaID)")
                playbackCandidates = freshCandidates
                playbackCandidateIndex = 0
                playbackCandidatesMediaID = normalizedMediaID
                let candidate = freshCandidates[0]
                updateAudioFormatLabels(for: candidate)
                playFromBeginning(url: candidate.url)
                return
            }
            print("⚠️ PlayerViewModel: exhaustiveRetry — iOS returned 0 candidates for id=\(normalizedMediaID)")
        } catch {
            guard !Task.isCancelled, currentVideoId == mediaID else { return }
            print("⚠️ PlayerViewModel: exhaustiveRetry — iOS failed for id=\(normalizedMediaID): \(error)")
        }

        // --- Attempt 2: Android client (muxed fallback) ---
        do {
            print("🔁 PlayerViewModel: exhaustiveRetry — trying Android client for id=\(normalizedMediaID)")
            let youtube = self.youtube.main
            let androidVideo = try await youtube.videoAndroid(id: normalizedMediaID)

            guard !Task.isCancelled, currentVideoId == mediaID else { return }

            // Use the standard candidate builder — same as iOS path
            let androidCandidates = PlaybackCandidateBuilder.fromVideo(
                androidVideo,
                preferredURL: nil,
                validUntil: Date().addingTimeInterval(3600)
            )

            if !androidCandidates.isEmpty {
                print("✅ PlayerViewModel: exhaustiveRetry — got \(androidCandidates.count) Android candidate(s) for id=\(normalizedMediaID)")
                playbackCandidates = androidCandidates
                playbackCandidateIndex = 0
                playbackCandidatesMediaID = normalizedMediaID
                let candidate = androidCandidates[0]
                updateAudioFormatLabels(for: candidate)
                playFromBeginning(url: candidate.url)
                return
            }
            print("⚠️ PlayerViewModel: exhaustiveRetry — Android returned no usable streams for id=\(normalizedMediaID)")
        } catch {
            guard !Task.isCancelled, currentVideoId == mediaID else { return }
            print("⚠️ PlayerViewModel: exhaustiveRetry — Android failed for id=\(normalizedMediaID): \(error)")
        }

        // --- Attempt 3: TV client (authenticated fallback) ---
        do {
            print("🔁 PlayerViewModel: exhaustiveRetry — trying TV client for id=\(normalizedMediaID)")
            let youtube = self.youtube.main
            let tvVideo = try await youtube.videoTV(id: normalizedMediaID)

            guard !Task.isCancelled, currentVideoId == mediaID else { return }

            let tvCandidates = PlaybackCandidateBuilder.fromVideo(
                tvVideo,
                preferredURL: nil,
                validUntil: Date().addingTimeInterval(3600)
            )

            if !tvCandidates.isEmpty {
                print("✅ PlayerViewModel: exhaustiveRetry — got \(tvCandidates.count) TV candidate(s) for id=\(normalizedMediaID)")
                playbackCandidates = tvCandidates
                playbackCandidateIndex = 0
                playbackCandidatesMediaID = normalizedMediaID
                let candidate = tvCandidates[0]
                updateAudioFormatLabels(for: candidate)
                playFromBeginning(url: candidate.url)
                return
            }
            print("❌ PlayerViewModel: exhaustiveRetry — TV returned no usable streams for id=\(normalizedMediaID)")
        } catch {
            guard !Task.isCancelled, currentVideoId == mediaID else { return }
            print("❌ PlayerViewModel: exhaustiveRetry — TV failed for id=\(normalizedMediaID): \(error)")
        }

        // All attempts exhausted
        playbackEngine.setIsPlaying(false)
        playbackError = originalError?.localizedDescription ?? "Unable to play this video"
    }

    private func canonicalPlaybackMediaID(_ mediaID: String) -> String {
        let trimmed = mediaID.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("youtube-") {
            return String(trimmed.dropFirst("youtube-".count))
        }
        return trimmed
    }

    private func startArtworkVideoProcessingIfNeeded(
        for mediaID: String,
        title: String,
        artist: String,
        albumName: String?
    ) {
        artworkVideoTask?.cancel()
        artworkVideoProgress = nil
        artworkVideoError = nil
        animatedArtworkVideoURL = nil

        let progressBridge = ArtworkVideoProgressBridge(viewModel: self, mediaID: mediaID)
        artworkVideoTask = Task { @MainActor [weak self, progressBridge] in
            guard let self else { return }
            self.logAnimatedArtwork("Processing started for id=\(mediaID)")

            do {
                guard let motionArtwork = await self.resolveMotionArtworkSource(
                    for: mediaID,
                    title: title,
                    artist: artist,
                    albumName: albumName
                ) else {
                    self.logAnimatedArtwork("No Animated Artwork found for id=\(mediaID)")
                    return
                }

                self.logAnimatedArtwork("Animated Artwork source found for id=\(mediaID): \(motionArtwork.sourceHLSURL.absoluteString)")

                guard !Task.isCancelled, self.currentVideoId == mediaID else { return }

                self.logAnimatedArtwork("Preparing motion artwork for id=\(mediaID)")
                self.artworkVideoStatus = .processing

                let localVideoURL = try await self.artworkVideoProcessor.prepareVideo(
                    for: mediaID,
                    cacheID: motionArtwork.videoCacheID,
                    sourceHLSURL: motionArtwork.sourceHLSURL,
                    progress: { progress in
                        progressBridge.report(progress)
                    }
                )

                guard !Task.isCancelled, self.currentVideoId == mediaID else { return }

                self.animatedArtworkVideoURL = localVideoURL
                self.artworkVideoProgress = 1
                self.artworkVideoStatus = .ready
                self.artworkVideoError = nil
                self.logAnimatedArtwork("Artwork found, transcoded, and loaded for id=\(mediaID): \(localVideoURL.lastPathComponent)")
                self.updateNowPlayingMetadata(force: true)
            } catch let error as ArtworkVideoProcessor.ArtworkVideoProcessorError {
                guard !Task.isCancelled, self.currentVideoId == mediaID else { return }

                if case .cancelled = error {
                    self.logAnimatedArtwork("Processing cancelled for id=\(mediaID)")
                    return
                }

                self.animatedArtworkVideoURL = nil
                self.artworkVideoProgress = nil
                self.artworkVideoStatus = .failed
                self.artworkVideoError = error.localizedDescription
                self.logAnimatedArtwork("Artwork found but failed transcoding for id=\(mediaID): \(error.localizedDescription)")
                print("⚠️ PlayerViewModel: Artwork video processing failed: \(error.localizedDescription)")
            } catch {
                guard !Task.isCancelled, self.currentVideoId == mediaID else { return }

                self.animatedArtworkVideoURL = nil
                self.artworkVideoProgress = nil
                self.artworkVideoStatus = .failed
                self.artworkVideoError = error.localizedDescription
                self.logAnimatedArtwork("Artwork found but failed transcoding for id=\(mediaID): \(error.localizedDescription)")
                print("⚠️ PlayerViewModel: Artwork video processing failed: \(error.localizedDescription)")
            }
        }
    }

    func logAnimatedArtwork(_ message: String) {
#if DEBUG
        guard Diagnostics.verboseArtworkLogsEnabled else { return }
        print("🖼️ PlayerViewModel: \(message)")
#endif
    }

    func logPlayback(_ message: String) {
#if DEBUG
        guard Diagnostics.verbosePlaybackLogsEnabled else { return }
        print("🎧 PlayerViewModel: \(message)")
#endif
    }

    private func resetArtworkVideoState() {
        artworkVideoTask?.cancel()
        artworkVideoTask = nil
        animatedArtworkVideoURL = nil
        artworkVideoProgress = nil
        artworkVideoStatus = .idle
        artworkVideoError = nil
    }

    private func observeCurrentItemStatus(_ item: AVPlayerItem) {
        currentItemStatusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            guard let self = self else { return }

            Task { @MainActor in
                switch item.status {
                case .readyToPlay:
                    self.logPlayback("AVPlayerItem ready to play")
                    if self.isPlaying {
                        self.player.play()
                    }
                    self.updateNowPlayingPlaybackInfo(force: true)
                    self.updateRemoteCommandState()
                case .failed:
                    let nsError = item.error as NSError?
                    let errorMessage = nsError?.localizedDescription ?? "unknown error"
                    let statusCode = Self.latestErrorStatusCode(for: item)
                    let errorCode = nsError?.code
                    let errorDomain = nsError?.domain
                    let failureReason = item.errorLog()?.events.last?.errorComment ?? item.errorLog()?.events.last?.serverAddress ?? "n/a"
                    let logSummary = item.errorLog()?.events.map { event in
                        "{domain=\(String(describing: event.errorDomain)) code=\(String(describing: event.errorStatusCode)) comment=\(String(describing: event.errorComment))}"
                    }.joined(separator: ", ") ?? "[]"
                    print("❌ PlayerViewModel: AVPlayerItem failed: message=\(errorMessage) domain=\(errorDomain ?? "n/a") code=\(errorCode.map(String.init) ?? "n/a") statusCode=\(statusCode.map(String.init) ?? "n/a") reason=\(failureReason)")
                    print("❌ PlayerViewModel: AVPlayerItem errorLog=\(logSummary)")

                    // Step 1: Try next local candidate (HLS → muxed → audio)
                    if self.attemptNextPlaybackCandidateIfAvailable(errorMessage: errorMessage) {
                        return
                    }

                    // Step 2: One-shot exhaustive retry — fetch fresh URLs from the network.
                    // We gate on exhaustiveRetryAttemptedIDs so this fires exactly once per
                    // track. Without the gate the loop is: fail → retry → same URL → fail → ...
                    if let mediaID = self.currentVideoId,
                       !self.exhaustiveRetryAttemptedIDs.contains(mediaID) {
                        self.exhaustiveRetryAttemptedIDs.insert(mediaID)
                        self.exhaustiveRetryTask?.cancel()
                        self.exhaustiveRetryTask = Task { [weak self] in
                            await self?.exhaustiveRetry(for: mediaID, originalError: item.error)
                        }
                        return
                    }

                    // Step 3: Exhaustive retry already attempted — fall through to standard handlers.
                    if self.handlePlaybackPermissionFailureIfNeeded(
                        errorMessage: errorMessage,
                        statusCode: statusCode,
                        errorDomain: errorDomain,
                        errorCode: errorCode
                    ) {
                        return
                    }

                    if self.advanceQueueAfterUnrecoverableFailure(errorMessage: errorMessage) {
                        return
                    }

                    self.playbackEngine.setIsPlaying(false)
                    self.playbackError = item.error?.localizedDescription ?? "Failed to load media"
                    self.updateNowPlayingPlaybackInfo(force: true)
                    self.updateRemoteCommandState()
                case .unknown:
                    self.logPlayback("AVPlayerItem status unknown")
                @unknown default:
                    break
                }
            }
        }
    }

    private static func latestErrorStatusCode(for item: AVPlayerItem) -> Int? {
        guard let events = item.errorLog()?.events else {
            return nil
        }

        for event in events.reversed() {
            let statusCode = Int(event.errorStatusCode)
            if statusCode != 0 {
                return statusCode
            }
        }

        return nil
    }

    private func observeCurrentItemEnd(_ item: AVPlayerItem) {
        removeCurrentItemEndObserver()
        currentItemEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.advanceToNextQueueEntry(triggeredByPlaybackEnd: true)
            }
        }
    }

    private func removeCurrentItemEndObserver() {
        if let currentItemEndObserver {
            NotificationCenter.default.removeObserver(currentItemEndObserver)
            self.currentItemEndObserver = nil
        }
    }

    // MARK: - Listening / Scrobbling Helpers

    private func startListeningSessionIfNeeded(for state: TrackPresentationState) {
        guard activeScrobbleSessionMediaID != state.mediaID else { return }

        finalizeCurrentListeningSession()
        activeScrobbleSessionMediaID = state.mediaID
        hasSubmittedScrobbleForActiveSession = false

        if lastFMSettings.localHistoryEnabled {
            currentListeningHistoryEntry = listeningHistoryStore.startSession(
                mediaID: state.mediaID,
                title: state.title,
                artist: state.artist,
                album: state.albumName,
                artworkURL: state.artworkURL,
                streamingService: state.streamingService.rawValue
            )
        } else {
            currentListeningHistoryEntry = nil
        }

        publishLastFMNowPlaying(for: state)
    }

    private func finalizeCurrentListeningSession() {
        lastFMScrobbleTask?.cancel()
        lastFMScrobbleTask = nil

        guard let entry = currentListeningHistoryEntry else {
            activeScrobbleSessionMediaID = nil
            hasSubmittedScrobbleForActiveSession = false
            return
        }

        listeningHistoryStore.finishSession(
            entry,
            endedAt: .now,
            listenedSeconds: currentTime,
            wasScrobbled: entry.wasScrobbled,
            scrobbledAt: entry.scrobbledAt
        )

        currentListeningHistoryEntry = nil
        activeScrobbleSessionMediaID = nil
        hasSubmittedScrobbleForActiveSession = false
    }

    private func publishLastFMNowPlaying(for state: TrackPresentationState) {
        guard lastFMSettings.enabled else { return }
        let item = makeLastFMPlaybackItem(for: state)
        Task { [lastFMScrobbler] in
            try? await lastFMScrobbler.recordNowPlaying(item)
        }
    }

    private func maybeSubmitLastFMScrobble() {
        guard !hasSubmittedScrobbleForActiveSession,
              lastFMSettings.enabled,
              let mediaID = activeScrobbleSessionMediaID,
              mediaID == currentVideoId,
              isPlaying else { return }

        let threshold = scrobbleThreshold(for: duration)
        guard threshold > 0, currentTime >= threshold else { return }

        hasSubmittedScrobbleForActiveSession = true
        let item = makeLastFMPlaybackItem(
            mediaID: mediaID,
            title: currentTitle,
            artist: currentArtist,
            album: currentAlbumNameHint,
            artworkURL: currentImageURL,
            duration: duration
        )

        lastFMScrobbleTask?.cancel()
        lastFMScrobbleTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.lastFMScrobbler.scrobble(item, playedAt: .now)
                guard let entry = self.currentListeningHistoryEntry else { return }
                self.listeningHistoryStore.markScrobbled(entry, scrobbledAt: .now)
            } catch {
                self.hasSubmittedScrobbleForActiveSession = false
            }
            self.lastFMScrobbleTask = nil
        }
    }

    private func scrobbleThreshold(for duration: Double) -> Double {
        guard duration.isFinite, duration > 0 else { return 240 }
        return min(duration / 2, 240)
    }

    private func makeLastFMPlaybackItem(
        mediaID: String,
        title: String,
        artist: String,
        album: String?,
        artworkURL: URL?,
        duration: Double
    ) -> LastFMPlaybackItem {
        LastFMPlaybackItem(
            mediaID: mediaID,
            title: title,
            artist: artist,
            album: album,
            artworkURL: artworkURL,
            durationSeconds: duration.isFinite && duration > 0 ? UInt(duration.rounded()) : nil
        )
    }

    private func makeLastFMPlaybackItem(for state: TrackPresentationState) -> LastFMPlaybackItem {
        makeLastFMPlaybackItem(
            mediaID: state.mediaID,
            title: state.title,
            artist: state.artist,
            album: state.albumName,
            artworkURL: state.artworkURL,
            duration: Double(state.durationHint ?? 0)
        )
    }

    private func handlePlaybackPermissionFailureIfNeeded(
        errorMessage: String,
        statusCode: Int?,
        errorDomain: String?,
        errorCode: Int?
    ) -> Bool {
        guard let mediaID = currentVideoId else { return false }
        guard supportsYouTubeCandidateRecovery else { return false }

        guard shouldAttemptPlaybackRecovery(
            for: errorMessage,
            statusCode: statusCode,
            errorDomain: errorDomain,
            errorCode: errorCode
        ) else {
            return false
        }

        let currentAttemptCount = playbackRecoveryAttemptCounts[mediaID, default: 0]
        guard currentAttemptCount < PlaybackRecoveryPolicy.maxAttemptsPerMediaID else {
            return false
        }

        playbackRecoveryAttemptCounts[mediaID] = currentAttemptCount + 1
        playbackRecoveryTask?.cancel()
        playbackRecoveryTask = Task { [weak self] in
            guard let self else { return }

            do {
                await self.metadataCache.remove(mediaID)
                self.mediaCacheStore.invalidatePlayback(for: mediaID)
                let candidates = try await self.resolvePlaybackCandidates(forID: mediaID, forceDecipher: true)

                guard !Task.isCancelled, self.currentVideoId == mediaID else { return }
                self.configurePlaybackCandidates(for: mediaID, candidates: candidates)
                self.playCurrentPlaybackCandidate()
                self.logPlayback(
                    "Recovered playback with refreshed stream URL for id=\(mediaID), attempt=\(currentAttemptCount + 1), status=\(statusCode.map(String.init) ?? "n/a")"
                )
            } catch {
                guard !Task.isCancelled, self.currentVideoId == mediaID else { return }
                self.playbackEngine.setIsPlaying(false)
                self.playbackError = error.localizedDescription
                self.updateNowPlayingPlaybackInfo(force: true)
                self.updateRemoteCommandState()
                print("❌ PlayerViewModel: Playback recovery failed for id=\(mediaID): \(error.localizedDescription)")
            }
        }

        return true
    }

    private func shouldAttemptPlaybackRecovery(
        for errorMessage: String,
        statusCode: Int?,
        errorDomain: String?,
        errorCode: Int?
    ) -> Bool {
        if let statusCode {
            if statusCode == 401 || statusCode == 403 || statusCode == 404 || statusCode == 410 || statusCode == 429 {
                return true
            }

            if statusCode >= 500 {
                return true
            }
        }

        if let errorDomain,
           let errorCode,
           errorDomain == NSURLErrorDomain {
            let recoverableCodes: Set<Int> = [-1100, -1102, -1011, -1009, -1005, -1004, -1003, -1001]
            if recoverableCodes.contains(errorCode) {
                return true
            }
        }

        if let errorDomain,
           let errorCode,
           errorDomain == AVFoundationErrorDomain {
            let recoverableCodes: Set<Int> = [-11800, -11819, -11850, -11867]
            if recoverableCodes.contains(errorCode) {
                return true
            }
        }

        let normalized = errorMessage.lowercased()
        return normalized.contains("permission")
            || normalized.contains("forbidden")
            || normalized.contains("403")
            || normalized.contains("not authorized")
            || normalized.contains("access denied")
            || normalized.contains("expired")
            || normalized.contains("signature")
            || normalized.contains("token")
            || normalized == "unknown error"
            || normalized.contains("failed to load")
            || normalized.contains("could not be loaded")
    }

    private func advanceQueueAfterUnrecoverableFailure(errorMessage: String) -> Bool {
        guard hasNextTrackInQueue else {
            return false
        }

        logPlayback("Advancing queue after unrecoverable failure: \(errorMessage)")
        advanceToNextQueueEntry(triggeredByPlaybackEnd: true)
        return true
    }

    private func handlePlaybackFailure(_ error: Error) {
        playbackEngine.pause()
        playbackError = error.localizedDescription
        updateNowPlayingPlaybackInfo(force: true)
        updateRemoteCommandState()
        
        let videoID = currentVideoId ?? "Unknown"
        print("❌ PlayerViewModel: Playback failed for ID [\(videoID)]: \(error.localizedDescription)")
        if let youtubeError = error as? YouTubeError {
             print("   Details: \(youtubeError)")
        }
    }

    // MARK: - Internal Setup


    private func setupRemoteCommands() {
        remoteCommandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.play() }
            return .success
        }
        remoteCommandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }
        remoteCommandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayPause() }
            return .success
        }
        remoteCommandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in self?.seek(to: positionEvent.positionTime) }
            return .success
        }
        remoteCommandCenter.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.skipToNext() }
            return .success
        }
        remoteCommandCenter.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.skipToPrevious() }
            return .success
        }

        updateRemoteCommandState()
    }

    private func play() {
        guard !isPlaying else {
            updateRemoteCommandState()
            return
        }

        reactivateAudioSessionIfNeeded()
        playbackEngine.play()
        updateNowPlayingPlaybackInfo(force: true)
        updateRemoteCommandState()
    }

    private func pause() {
        guard isPlaying else {
            updateRemoteCommandState()
            return
        }

        playbackEngine.pause()
        updateNowPlayingPlaybackInfo(force: true)
        updateRemoteCommandState()
    }

    func updateRemoteCommandState() {
        remoteCommandCenter.playCommand.isEnabled = !isPlaying && currentVideoId != nil
        remoteCommandCenter.pauseCommand.isEnabled = isPlaying
        remoteCommandCenter.togglePlayPauseCommand.isEnabled = currentVideoId != nil
        remoteCommandCenter.changePlaybackPositionCommand.isEnabled = currentVideoId != nil
        remoteCommandCenter.nextTrackCommand.isEnabled = canSkipForward
        remoteCommandCenter.previousTrackCommand.isEnabled = canSkipBackward
    }

    #if os(iOS)
    private func setupVolumeButtonSkip() {
        VolumeButtonSkipController.shared.configure()
        VolumeButtonSkipController.shared.onSkipForward = { [weak self] in
            self?.skipToNext()
        }
        VolumeButtonSkipController.shared.onSkipBackward = { [weak self] in
            self?.skipToPrevious()
        }
        VolumeButtonSkipController.shared.isPlaying = { [weak self] in
            self?.isPlaying ?? false
        }
        VolumeButtonSkipController.shared.canSkipForward = { [weak self] in
            self?.canSkipForward ?? false
        }
        VolumeButtonSkipController.shared.canSkipBackward = { [weak self] in
            self?.canSkipBackward ?? false
        }
    }
    #endif

}

private final class WeakPlayerViewModelBox: @unchecked Sendable {
    weak var value: PlayerViewModel?

    init(_ value: PlayerViewModel) {
        self.value = value
    }
}

private final class ArtworkVideoProgressBridge: @unchecked Sendable {
    private let viewModelBox: WeakPlayerViewModelBox
    private let mediaID: String

    init(viewModel: PlayerViewModel, mediaID: String) {
        self.viewModelBox = WeakPlayerViewModelBox(viewModel)
        self.mediaID = mediaID
    }

    nonisolated func report(_ progress: Double) {
        let viewModelBox = viewModelBox
        let mediaID = mediaID

        Task { @MainActor in
            guard let viewModel = viewModelBox.value,
                  viewModel.currentVideoId == mediaID else { return }
            viewModel.artworkVideoProgress = progress
            viewModel.artworkVideoStatus = .processing
        }
    }
}
