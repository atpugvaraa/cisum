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
import Utilities
import Services
import Models
import DesignSystem
import ProviderSDK


public typealias PlaybackCandidate = Services.PlaybackCandidate

#if os(iOS)
import UIKit
#endif

import YouTubeSDK

#if canImport(iTunesKit)
import iTunesKit
#endif

#if canImport(LyricsKit)
import LyricsKit
#endif

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

    enum PlaybackRecoveryPolicy {
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
        case userQueue
    }

    public enum StreamingService: String {
        case youtube = "YouTube"
        case youtubeMusic = "YouTube Music"
        case spotify = "Spotify"
        case external = "External"
    }




    @Observable
    @MainActor
    public final class PlaybackProgressState {
        public var duration: Double = 0.0
        public var currentTime: Double = 0.0
        
        public init() {}
    }

    struct TrackPresentationState {
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
        let queueIdentity: QueueIdentitySnapshot
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
    let youtube: YouTube
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



    // Private
    private var timeObserver: Any?
    var currentLoadTask: Task<Void, Never>?
    var artworkLoadTask: Task<Void, Never>?
    private var artworkVideoTask: Task<Void, Never>?
    var lyricsLoadTask: Task<Void, Never>?
    var playbackRecoveryTask: Task<Void, Never>?
    private var exhaustiveRetryTask: Task<Void, Never>?
    /// Tracks which mediaIDs have already had exhaustiveRetry attempted.
    /// Prevents the infinite loop: fail → retry → same URL → fail → retry...
    private var exhaustiveRetryAttemptedIDs: Set<String> = []
    var playbackRecoveryAttemptCounts: [String: Int] = [:]
    var playbackCandidates: [PlaybackCandidate] = []
    var playbackCandidateIndex: Int = 0
    var playbackCandidatesMediaID: String?
    var pendingPlaybackFormatOverride: (quality: String, codec: String)?
    private var currentAlbumNameHint: String?
    private var currentQueueIdentity: QueueIdentitySnapshot?
    var playbackQueue: [PlaybackQueueEntry] = [] {
        didSet {
            updateQueuePreviewItems()
        }
    }

    // Patch 3: Duplicate-load guard. Prevents multiple concurrent loads for the
    // same mediaID (e.g. rapid taps). Mirrors SmartTubeIOS's isLoading check.
    var isLoading: Bool = false
    var loadingMediaID: String?

    // Patch 4: AsyncStream-based item status observer — replaces KVO.
    // Cancelling itemObserverTask before replaceCurrentItem ensures stale
    // callbacks from the previous item never fire against the new state.
    private var itemObserverTask: Task<Void, Never>?

    // Patch 5: Async notification-based end observer — replaces NotificationCenter handle.
    private var endObserverTask: Task<Void, Never>?
    var webHLSProxyLoader: YTHLSProxyLoader? // Prevents ARC release during playback

    // Patch 7: Capture current playhead before a URL refresh so we can restore
    // the position once the new item reaches .readyToPlay.
    var savedPositionToRestore: TimeInterval?
    private let remoteCommandCenter = MPRemoteCommandCenter.shared()
    let metadataCache: any VideoMetadataCaching
    #if canImport(iTunesKit)
    let itunes = iTunesKit()
    #endif
    let mediaCacheStore: MediaCacheStore
    let settings: PrefetchSettings
    let playbackMetricsStore: any PlaybackMetricsRecording
    private let lastFMScrobbler: LastFMScrobbler
    private let lastFMSettings: LastFMSettings
    private let listeningHistoryStore: ListeningHistoryStore
    private let streamingProviderSettings: StreamingProviderSettings
    let radioSessionStore: RadioSessionStore
    private var currentListeningHistoryEntry: ListeningHistoryEntry?
    private var activeScrobbleSessionMediaID: String?
    private var hasSubmittedScrobbleForActiveSession = false
    private var lastFMScrobbleTask: Task<Void, Never>?
#if os(iOS)
    var artworkColorExtractor = ImageColorExtractor.shared
#endif

#if os(iOS)
    var nowPlayingState = NowPlayingState()
    var lastPublishedNowPlayingState: NowPlayingState?
    var currentArtworkResource: CachedNowPlayingArtworkResource?
    var currentArtworkMediaID: String?
    var artworkCache: [String: CachedNowPlayingArtworkResource] = [:]
    var artworkAccentCache: [String: (artworkURL: URL, color: Color)] = [:]
    var artworkPaletteCache: [String: (artworkURL: URL, palette: ImageColorPalette?)] = [:]
    var accentLoadTask: Task<Void, Never>?

    var interruptionObserver: NSObjectProtocol?
    var routeChangeObserver: NSObjectProtocol?
    var wasPlayingBeforeInterruption = false
#endif

    var hasNextTrackInQueue: Bool {
        guard let queuePosition else { return false }
        return queuePosition + 1 < playbackQueue.count
    }

    private var hasPreviousTrackInQueue: Bool {
        guard let queuePosition else { return false }
        return queuePosition > 0
    }

    var radioSeedVideoID: String?
    var radioPlaylistID: String?
    var radioContinuationToken: String?
    var radioAutoplayTask: Task<Void, Never>?
    var radioContinuationTask: Task<Void, Never>?
    var isLoadingRadioContinuation = false
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
        artworkColorExtractor: ImageColorExtractor
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

    func preparePlaybackSession(for state: TrackPresentationState, preserveQueue: Bool) {
        if !preserveQueue {
            clearQueueContext()
        }

        resetHiResAvailabilityState()
        currentQueueIdentity = state.queueIdentity
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

    func makeQueueIdentitySnapshot(
        mediaID: String,
        title: String,
        artist: String,
        activeRepresentationKey: String?,
        hydrationState: [String],
        candidateSnapshot: [QueueCandidateSnapshot]
    ) -> QueueIdentitySnapshot {
        let fingerprint = "\(title.lowercased())|\(artist.lowercased())|\(mediaID.lowercased())"
        return QueueIdentitySnapshot(
            canonicalID: canonicalQueueID(for: fingerprint, fallback: mediaID),
            activeRepresentationKey: activeRepresentationKey,
            hydrationState: hydrationState,
            candidateSnapshot: candidateSnapshot
        )
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

    // MARK: - Loaders extracted to PlayerViewModel+Loading.swift

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

    func advanceToNextQueueEntry(triggeredByPlaybackEnd: Bool) {
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
        // Patch 4 & 5: Cancel both async observers before replacing the item.
        itemObserverTask?.cancel()
        itemObserverTask = nil
        endObserverTask?.cancel()
        endObserverTask = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
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
                let candidates = try await self.resolvePlaybackCandidates(
                    forID: id,
                    title: self.currentTitle,
                    artist: self.currentArtist
                )

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

    func load(entry: PlaybackQueueEntry) {
        self.webHLSProxyLoader = nil
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

    func loadExternalTrack(_ track: ExternalQueueTrack, preserveQueue: Bool) {
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
            durationHint: nil,
            queueIdentity: makeQueueIdentitySnapshot(
                mediaID: normalizedMediaID,
                title: displayTitle,
                artist: displayArtist,
                activeRepresentationKey: nil,
                hydrationState: ["metadataResolved"],
                candidateSnapshot: []
            )
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
        currentQueueIdentity = nil
        updateRemoteCommandState()
    }

    // MARK: - Queue Management extracted to PlayerViewModel+Queue.swift

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
            durationHint: prepared.durationHint,
            queueIdentity: prepared.queueIdentity
        )
        preparePlaybackSession(for: presentation, preserveQueue: true)

        if prepared.playbackCandidates.isEmpty {
            resetPlaybackCandidates(for: prepared.mediaID)
        } else {
            configurePlaybackCandidates(for: prepared.mediaID, candidates: prepared.playbackCandidates)
        }

        // Cancel stale observers before installing the preloaded item.
        itemObserverTask?.cancel()
        itemObserverTask = nil
        endObserverTask?.cancel()
        endObserverTask = nil

        player.replaceCurrentItem(with: prepared.item)

#if os(iOS)
        if #available(iOS 14.0, *) {
            player.audiovisualBackgroundPlaybackPolicy = .continuesIfPossible
        }
#endif

        playbackEngine.reactivateSession()
        observeItemStatus(prepared.item)
        observeItemEnd(prepared.item)

        playbackEngine.resetProgress()
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



    private func playFromBeginning(url: URL, headers: [String: String]? = nil) {
        logPlayback("Creating playback item url=\(url.absoluteString) host=\(url.host ?? "unknown") service=\(currentStreamingServiceName)")
        let item = makePlayerItem(for: url, headers: headers)

        // Patch 4 & 5: Cancel stale observers before replacing the item so a
        // previous item's .failed callback cannot fire against the new state.
        itemObserverTask?.cancel()
        itemObserverTask = nil
        endObserverTask?.cancel()
        endObserverTask = nil

        player.replaceCurrentItem(with: item)

        #if os(iOS)
        if #available(iOS 14.0, *) {
            player.audiovisualBackgroundPlaybackPolicy = .continuesIfPossible
        }
        #endif

        // Patch 6 (deferred audio session): activate the session at load time,
        // not at init, so we only take the session when the user actually plays.
        playbackEngine.reactivateSession()

        // Patch 4: Wire the AsyncStream-based status observer *after* replaceCurrentItem
        // so .readyToPlay is guaranteed to fire while the task is alive.
        observeItemStatus(item)
        // Patch 5: Wire the async end observer.
        observeItemEnd(item)

        playbackEngine.resetProgress()
        playbackEngine.play()

        updateNowPlayingMetadata()
        updateRemoteCommandState()
        preloadNextQueueEntryIfNeeded()
    }



    private func resetPlaybackCandidates(for mediaID: String) {
        playbackCandidatesMediaID = mediaID
        playbackCandidates = []
        playbackCandidateIndex = 0
    }

    private func resetPlaybackRecoveryState(for mediaID: String) {
        playbackRecoveryAttemptCounts.removeValue(forKey: mediaID)
    }

    var supportsYouTubeCandidateRecovery: Bool {
        currentStreamingServiceName == StreamingService.youtube.rawValue
            || currentStreamingServiceName == StreamingService.youtubeMusic.rawValue
    }

    func playCurrentPlaybackCandidate() {
        guard playbackCandidateIndex < playbackCandidates.count else {
            if let fallback = playbackCandidates.first {
                logPlayback("Playback candidate index out of range, retrying first candidate for id=\(playbackCandidatesMediaID ?? "unknown")")
                updateAudioFormatLabels(for: fallback)
                playFromBeginning(url: fallback.url, headers: fallback.headers)
            }
            return
        }

        let candidate = playbackCandidates[playbackCandidateIndex]
        logPlayback(
            "Trying playback candidate #\(playbackCandidateIndex + 1) kind=\(candidate.streamKind.rawValue) for id=\(playbackCandidatesMediaID ?? "unknown")"
        )
        updateAudioFormatLabels(for: candidate)
        playFromBeginning(url: candidate.url, headers: candidate.headers)
    }



    // Removed exhaustiveRetry

    func canonicalPlaybackMediaID(_ mediaID: String) -> String {
        let trimmed = mediaID.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("youtube-") {
            return String(trimmed.dropFirst("youtube-".count))
        }
        return trimmed
    }

    func startArtworkVideoProcessingIfNeeded(
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

    // Patch 4: AsyncStream-based item status observer.
    // The task is stored so it can be cancelled before replaceCurrentItem,
    // eliminating the race window where a stale .failed fires against new state.
    private func observeItemStatus(_ item: AVPlayerItem) {
        itemObserverTask?.cancel()
        itemObserverTask = Task { @MainActor [weak self, weak item] in
            guard let self, let item else { return }
            for await status in item.statusStream where !Task.isCancelled {
                guard item === self.player.currentItem else { return }
                switch status {
                case .readyToPlay:
                    self.logPlayback("AVPlayerItem ready to play")
                    // Patch 7: Restore saved position after a URL refresh.
                    if let position = self.savedPositionToRestore {
                        self.savedPositionToRestore = nil
                        self.playbackEngine.seek(to: position)
                    }
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
                    // Patch 6: No fullReset() — reuse the existing AVPlayer instance.
                    if let mediaID = self.playbackCandidatesMediaID,
                       !self.exhaustiveRetryAttemptedIDs.contains(mediaID) {
                        self.exhaustiveRetryAttemptedIDs.insert(mediaID)
                        // Patch 7: Capture position before we swap the URL.
                        self.savedPositionToRestore = self.currentTime > 1 ? self.currentTime : nil
                        self.exhaustiveRetryTask?.cancel()
                        self.exhaustiveRetryTask = Task { @MainActor [weak self] in
                            guard let self else { return }
                            do {
                                let freshCandidates = try await self.resolvePlaybackCandidates(
                                    forID: mediaID,
                                    title: self.currentTitle,
                                    artist: self.currentArtist,
                                    forceDecipher: true
                                )
                                guard !Task.isCancelled, self.currentVideoId == mediaID else { return }
                                if !freshCandidates.isEmpty {
                                    self.configurePlaybackCandidates(for: mediaID, candidates: freshCandidates)
                                    self.playCurrentPlaybackCandidate()
                                }
                            } catch {
                                guard !Task.isCancelled, self.currentVideoId == mediaID else { return }
                                self.savedPositionToRestore = nil
                                self.playbackEngine.setIsPlaying(false)
                                self.playbackError = error.localizedDescription
                            }
                        }
                        return
                    }

                    // Step 3: Exhaustive retry already attempted — fall through.
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
            if statusCode != 0 { return statusCode }
        }
        return nil
    }

    // Patch 5: Async notification-based end observer.
    // Stored as a Task so it is automatically cancelled before each replaceCurrentItem.
    private func observeItemEnd(_ item: AVPlayerItem) {
        endObserverTask?.cancel()
        endObserverTask = Task { @MainActor [weak self, weak item] in
            guard let self, let item else { return }
            let notifications = NotificationCenter.default.notifications(
                named: .AVPlayerItemDidPlayToEndTime,
                object: item
            )
            for await _ in notifications where !Task.isCancelled {
                guard item === self.player.currentItem else { return }
                self.advanceToNextQueueEntry(triggeredByPlaybackEnd: true)
                return
            }
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
