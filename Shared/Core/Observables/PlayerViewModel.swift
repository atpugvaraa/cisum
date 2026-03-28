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
import iTunesKit

#if os(iOS)
import UIKit
#endif

@Observable
@MainActor
final class PlayerViewModel {

    private enum CachePolicy {
        static let playbackURLTTL: TimeInterval = 60 * 20
        static let highQualityArtworkTTL: TimeInterval = 60 * 60 * 24 * 14
        static let motionArtworkSourceTTL: TimeInterval = 60 * 60 * 24
    }

    private enum Diagnostics {
        static let verbosePlaybackLogsEnabled = false
        static let verboseArtworkLogsEnabled = false
    }

    enum ArtworkVideoProcessingStatus: Equatable {
        case idle
        case processing
        case ready
        case failed
    }

    // MARK: - State
    var player: AVPlayer
    private let youtube: YouTube
    private let artworkVideoProcessor: ArtworkVideoProcessor
    var currentVideoId: String?
    var playbackError: String?
    var animatedArtworkVideoURL: URL?
    var artworkVideoProgress: Double?
    var artworkVideoStatus: ArtworkVideoProcessingStatus = .idle
    var artworkVideoError: String?

    // Track Info
    var currentTitle: String = "Not Playing"
    var currentArtist: String = ""
    var currentImageURL: URL?
    var isExplicit: Bool = false

    var isPlaying = false

    // Progress
    var duration: Double = 0.0
    var currentTime: Double = 0.0

    // Private
    private var timeObserver: Any?
    private var currentLoadTask: Task<Void, Never>?
    private var artworkLoadTask: Task<Void, Never>?
    private var artworkVideoTask: Task<Void, Never>?
    private var playbackRecoveryTask: Task<Void, Never>?
    private var playbackRecoveryAttemptedIDs: Set<String> = []
    private var playbackCandidates: [URL] = []
    private var playbackCandidateIndex: Int = 0
    private var playbackCandidatesMediaID: String?
    private var currentItemStatusObservation: NSKeyValueObservation?
    private let remoteCommandCenter = MPRemoteCommandCenter.shared()
    private let metadataCache = VideoMetadataCache.shared
    private let itunes = iTunesKit()
    private let mediaCacheStore: MediaCacheStore?
    private let settings: PrefetchSettings

#if os(iOS)
    private struct NowPlayingState: Equatable {
        var mediaID: String?
        var title: String = "Not Playing"
        var artist: String = ""
        var artworkURL: URL?
        var duration: Double = 0
        var elapsedTime: Double = 0
        var playbackRate: Float = 0
    }

    private struct CachedNowPlayingArtworkResource {
        let url: URL
        let data: Data
        let size: CGSize
    }

    private var nowPlayingState = NowPlayingState()
    private var lastPublishedNowPlayingState: NowPlayingState?
    private var currentArtworkResource: CachedNowPlayingArtworkResource?
    private var currentArtworkMediaID: String?
    private var artworkCache: [String: CachedNowPlayingArtworkResource] = [:]
#endif

#if os(iOS)
    private var interruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?
    private var wasPlayingBeforeInterruption = false
#endif

    init(
        youtube: YouTube = .shared,
        settings: PrefetchSettings = .shared,
        artworkVideoProcessor: ArtworkVideoProcessor = .shared,
        mediaCacheStore: MediaCacheStore? = nil
    ) {
        self.youtube = youtube
        self.settings = settings
        self.artworkVideoProcessor = artworkVideoProcessor
        self.mediaCacheStore = mediaCacheStore
        self.player = AVPlayer()

        configureAudioSession()
        configurePlayerForBackgroundPlayback()
        setupRemoteCommands()
        setupTimeObserver()
        setupAudioLifecycleObservers()
    }

    // MARK: - Loaders

    func load(song: YouTubeMusicSong) {
        let tapStartedAt = Date()

        currentTitle = song.title
        currentArtist = song.artistsDisplay
        currentImageURL = song.thumbnailURL
        isExplicit = song.isExplicit
        currentVideoId = song.videoId
        playbackError = nil
        currentTime = 0
        duration = 0
        resetPlaybackCandidates(for: song.videoId)
        playbackRecoveryAttemptedIDs.remove(song.videoId)
        playbackRecoveryTask?.cancel()
        playbackRecoveryTask = nil
        resetArtworkVideoState()
#if os(iOS)
        artworkLoadTask?.cancel()
        applyCachedArtworkIfAvailable(for: song.videoId)
#endif
        updateNowPlayingMetadata(force: true)
#if os(iOS)
        loadNowPlayingArtwork(for: song.videoId, title: song.title, artist: song.artistsDisplay, fallbackURL: song.thumbnailURL)
#endif

        currentLoadTask?.cancel()
        currentLoadTask = Task {
            if Task.isCancelled { return }

            do {
                let candidates = try await self.resolvePlaybackCandidates(forID: song.videoId)

                if Task.isCancelled { return }

                self.configurePlaybackCandidates(for: song.videoId, candidates: candidates)
                self.playCurrentPlaybackCandidate()
                self.startArtworkVideoProcessingIfNeeded(
                    for: song.videoId,
                    title: song.title,
                    artist: song.artistsDisplay
                )
                self.logPlayback("Started playback for song id=\(song.videoId)")

                if settings.metricsEnabled {
                    let elapsed = Date().timeIntervalSince(tapStartedAt) * 1000
                    await PlaybackMetricsStore.shared.recordTapToPlay(durationMs: elapsed)
                }
            } catch {
                self.handlePlaybackFailure(error)
            }
        }
    }

    func load(video: YouTubeVideo) {
        let tapStartedAt = Date()
        let fallbackURL = URL(string: video.thumbnailURL ?? "")

        currentTitle = video.title
        currentArtist = video.author
        currentImageURL = fallbackURL
        isExplicit = false
        currentVideoId = video.id
        playbackError = nil
        currentTime = 0
        duration = 0
        resetPlaybackCandidates(for: video.id)
        playbackRecoveryAttemptedIDs.remove(video.id)
        playbackRecoveryTask?.cancel()
        playbackRecoveryTask = nil
        resetArtworkVideoState()
#if os(iOS)
        artworkLoadTask?.cancel()
        applyCachedArtworkIfAvailable(for: video.id)
#endif
        updateNowPlayingMetadata(force: true)
#if os(iOS)
        loadNowPlayingArtwork(for: video.id, title: video.title, artist: video.author, fallbackURL: fallbackURL)
#endif

        currentLoadTask?.cancel()
        currentLoadTask = Task {
            if Task.isCancelled { return }

            do {
                let candidates = try await self.resolvePlaybackCandidates(forID: video.id)

                if Task.isCancelled { return }

                self.configurePlaybackCandidates(for: video.id, candidates: candidates)
                self.playCurrentPlaybackCandidate()
                self.startArtworkVideoProcessingIfNeeded(
                    for: video.id,
                    title: video.title,
                    artist: video.author
                )
                self.logPlayback("Started playback for video id=\(video.id)")

                if settings.metricsEnabled {
                    let elapsed = Date().timeIntervalSince(tapStartedAt) * 1000
                    await PlaybackMetricsStore.shared.recordTapToPlay(durationMs: elapsed)
                }
            } catch {
                self.handlePlaybackFailure(error)
            }
        }
    }

    // MARK: - Controls

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func seek(to seconds: Double) {
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: time) { [weak self] _ in
            Task { @MainActor in
                self?.updateNowPlayingPlaybackInfo(force: true)
            }
        }
    }

    /// Reload the current video with current playback configuration.
    func reloadCurrentVideo() {
        guard let id = currentVideoId else { return }
        resetPlaybackCandidates(for: id)
        currentLoadTask?.cancel()
        currentLoadTask = Task {
            if Task.isCancelled { return }
            do {
                let candidates = try await self.resolvePlaybackCandidates(forID: id)

                if Task.isCancelled { return }

                self.configurePlaybackCandidates(for: id, candidates: candidates)
                self.playCurrentPlaybackCandidate()
                self.startArtworkVideoProcessingIfNeeded(
                    for: id,
                    title: currentTitle,
                    artist: currentArtist
                )
            } catch {
                self.playbackError = error.localizedDescription
            }
        }
    }

    #if os(iOS)
    func handleScenePhaseChange(_ phase: ScenePhase) {
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

    // MARK: - Playback Resolution

    private func resolvePlaybackEntry(forID id: String) async throws -> VideoMetadataCache.Entry {
        do {
            return try await metadataCache.resolve(id: id, metricsEnabled: settings.metricsEnabled) { key in
                try await self.youtube.main.video(id: key)
            }
        } catch {
            print("⚠️ PlayerViewModel: First resolve failed for id=\(id): \(error.localizedDescription). Retrying once...")
            try? await Task.sleep(nanoseconds: 350_000_000)

            return try await metadataCache.resolve(id: id, metricsEnabled: settings.metricsEnabled) { key in
                try await self.youtube.main.video(id: key)
            }
        }
    }

    private func resolvePlaybackCandidates(forID id: String) async throws -> [URL] {
        if let mediaCacheStore,
           let cachedCandidates = mediaCacheStore.playbackCandidates(
                for: id,
                maxAge: CachePolicy.playbackURLTTL
           ),
           !cachedCandidates.isEmpty {
            logPlayback("Using cached playback candidates for id=\(id)")
            return cachedCandidates
        }

        let entry = try await resolvePlaybackEntry(forID: id)
        let candidates = Self.makePlaybackCandidates(
            from: entry.video,
            preferredURL: entry.resolvedURL
        )

        mediaCacheStore?.savePlaybackResolution(
            mediaID: id,
            preferredURL: entry.resolvedURL,
            video: entry.video
        )

        return candidates
    }

    private func playFromBeginning(url: URL) {
        let item = makePlayerItem(for: url)
        observeCurrentItemStatus(item)
        player.replaceCurrentItem(with: item)

        #if os(iOS)
        if #available(iOS 14.0, *) {
            player.audiovisualBackgroundPlaybackPolicy = .continuesIfPossible
        }
        #endif

        seek(to: .zero)
        currentTime = 0
        duration = 0
        isPlaying = true
        player.play()

        updateNowPlayingMetadata()
        updateRemoteCommandState()
    }

    private func makePlayerItem(for url: URL) -> AVPlayerItem {
        let headers: [String: String] = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 26_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Mobile/15E148 Safari/604.1",
            "Referer": "https://www.youtube.com/",
            "Origin": "https://www.youtube.com"
        ]

        let asset = AVURLAsset(
            url: url,
            options: ["AVURLAssetHTTPHeaderFieldsKey": headers]
        )
        return AVPlayerItem(asset: asset)
    }

    private func configurePlaybackCandidates(for mediaID: String, candidates: [URL]) {
        playbackCandidatesMediaID = mediaID
        playbackCandidates = candidates
        playbackCandidateIndex = 0
        logPlayback("Prepared \(candidates.count) playback candidate(s) for id=\(mediaID)")
        let hostSummary = candidates
            .map { $0.host ?? "unknown-host" }
            .joined(separator: " | ")
        logPlayback("Candidate hosts for id=\(mediaID): \(hostSummary)")
    }

    private func resetPlaybackCandidates(for mediaID: String) {
        playbackCandidatesMediaID = mediaID
        playbackCandidates = []
        playbackCandidateIndex = 0
    }

    private func playCurrentPlaybackCandidate() {
        guard playbackCandidateIndex < playbackCandidates.count else {
            if let fallback = playbackCandidates.first {
                logPlayback("Playback candidate index out of range, retrying first candidate for id=\(playbackCandidatesMediaID ?? "unknown")")
                playFromBeginning(url: fallback)
            }
            return
        }

        let candidateURL = playbackCandidates[playbackCandidateIndex]
        logPlayback("Trying playback candidate #\(playbackCandidateIndex + 1) for id=\(playbackCandidatesMediaID ?? "unknown")")
        playFromBeginning(url: candidateURL)
    }

    private func attemptNextPlaybackCandidateIfAvailable(errorMessage: String) -> Bool {
        guard let mediaID = currentVideoId,
              playbackCandidatesMediaID == mediaID,
              playbackCandidateIndex + 1 < playbackCandidates.count else {
            return false
        }

        playbackCandidateIndex += 1
        let candidateURL = playbackCandidates[playbackCandidateIndex]
        logPlayback("Trying fallback playback URL #\(playbackCandidateIndex + 1) for id=\(mediaID) after error=\(errorMessage)")
        playFromBeginning(url: candidateURL)
        return true
    }

    private func startArtworkVideoProcessingIfNeeded(
        for mediaID: String,
        title: String,
        artist: String
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
                guard let sourceHLSURL = await self.resolveMotionArtworkURL(
                    for: mediaID,
                    title: title,
                    artist: artist
                ) else {
                    self.logAnimatedArtwork("No Animated Artwork found for id=\(mediaID)")
                    return
                }

                self.logAnimatedArtwork("Animated Artwork source found for id=\(mediaID): \(sourceHLSURL.absoluteString)")

                guard !Task.isCancelled, self.currentVideoId == mediaID else { return }

                self.logAnimatedArtwork("Preparing motion artwork for id=\(mediaID)")
                self.artworkVideoStatus = .processing

                let localVideoURL = try await self.artworkVideoProcessor.prepareVideo(
                    for: mediaID,
                    sourceHLSURL: sourceHLSURL,
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

    private func logAnimatedArtwork(_ message: String) {
#if DEBUG
        guard Diagnostics.verboseArtworkLogsEnabled else { return }
        print("🖼️ PlayerViewModel: \(message)")
#endif
    }

    private func logPlayback(_ message: String) {
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
                    let errorMessage = item.error?.localizedDescription ?? "unknown error"
                    print("❌ PlayerViewModel: AVPlayerItem failed: \(errorMessage)")

                    if self.attemptNextPlaybackCandidateIfAvailable(errorMessage: errorMessage) {
                        return
                    }

                    if self.handlePlaybackPermissionFailureIfNeeded(errorMessage: errorMessage) {
                        return
                    }

                    self.isPlaying = false
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

    private func handlePlaybackPermissionFailureIfNeeded(errorMessage: String) -> Bool {
        guard let mediaID = currentVideoId else { return false }
        guard shouldAttemptPlaybackRecovery(for: errorMessage) else { return false }
        guard !playbackRecoveryAttemptedIDs.contains(mediaID) else { return false }

        playbackRecoveryAttemptedIDs.insert(mediaID)
        playbackRecoveryTask?.cancel()
        playbackRecoveryTask = Task { [weak self] in
            guard let self else { return }

            do {
                await self.metadataCache.remove(mediaID)
                self.mediaCacheStore?.invalidatePlayback(for: mediaID)
                let candidates = try await self.resolvePlaybackCandidates(forID: mediaID)

                guard !Task.isCancelled, self.currentVideoId == mediaID else { return }
                self.configurePlaybackCandidates(for: mediaID, candidates: candidates)
                self.playCurrentPlaybackCandidate()
                self.logPlayback("Recovered playback with refreshed stream URL for id=\(mediaID)")
            } catch {
                guard !Task.isCancelled, self.currentVideoId == mediaID else { return }
                self.isPlaying = false
                self.playbackError = error.localizedDescription
                self.updateNowPlayingPlaybackInfo(force: true)
                self.updateRemoteCommandState()
                print("❌ PlayerViewModel: Playback recovery failed for id=\(mediaID): \(error.localizedDescription)")
            }
        }

        return true
    }

    private func shouldAttemptPlaybackRecovery(for errorMessage: String) -> Bool {
        let normalized = errorMessage.lowercased()
        return normalized.contains("permission")
            || normalized.contains("forbidden")
            || normalized.contains("403")
            || normalized.contains("not authorized")
            || normalized.contains("unknown error")
            || normalized.contains("failed")
    }

    nonisolated private static func makePlaybackCandidates(
        from video: YouTubeVideo,
        preferredURL: URL
    ) -> [URL] {
        var candidates: [URL] = [preferredURL]

        if let hls = video.hlsURL {
            candidates.append(hls)
        }

        if let muxedURLString = video.bestMuxedStream?.url,
           let muxedURL = URL(string: muxedURLString) {
            candidates.append(muxedURL)
        }

        if let audio = video.bestAudioStream,
           let audioURLString = audio.url,
           let audioURL = URL(string: audioURLString),
           isLikelyAVPlayerCompatibleAudioStream(audio.mimeType) {
            candidates.append(audioURL)
        }

        var seen: Set<String> = []
        return candidates.filter { url in
            let key = url.absoluteString
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }

    nonisolated private static func isLikelyAVPlayerCompatibleAudioStream(_ mimeType: String) -> Bool {
        let normalized = mimeType.lowercased()
        if normalized.contains("webm") {
            return false
        }
        return normalized.contains("mp4")
            || normalized.contains("mpeg")
            || normalized.contains("aac")
            || normalized.contains("mp3")
    }

    private func handlePlaybackFailure(_ error: Error) {
        player.pause()
        isPlaying = false
        playbackError = error.localizedDescription
        updateNowPlayingPlaybackInfo(force: true)
        updateRemoteCommandState()
        print("❌ PlayerViewModel: Playback failed: \(error.localizedDescription)")
    }

    // MARK: - Audio Session

    private func configureAudioSession() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, policy: .longFormAudio)
            try session.setActive(true)
        } catch {
            print("❌ PlayerViewModel: Failed to configure audio session: \(error)")
        }
        #endif
    }

    private func configurePlayerForBackgroundPlayback() {
        #if os(iOS)
        player.automaticallyWaitsToMinimizeStalling = true
        if #available(iOS 14.0, *) {
            player.audiovisualBackgroundPlaybackPolicy = .continuesIfPossible
        }
        #endif
    }

    #if os(iOS)
    private func setupAudioLifecycleObservers() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            let userInfo = notification.userInfo
            let typeValue = userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let optionsValue = userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt
            Task { @MainActor in
                self.handleAudioSessionInterruption(typeValue: typeValue, optionsValue: optionsValue)
            }
        }

        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            Task { @MainActor in
                self.handleAudioRouteChange(reasonValue: reasonValue)
            }
        }
    }

    private func handleAudioSessionInterruption(typeValue: UInt?, optionsValue: UInt?) {
        guard let typeValue,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            wasPlayingBeforeInterruption = isPlaying
            player.pause()
            isPlaying = false
            updateNowPlayingPlaybackInfo(force: true)
            updateRemoteCommandState()
            print("⚠️ PlayerViewModel: Audio interruption began")

        case .ended:
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue ?? 0)
            let shouldResume = options.contains(.shouldResume)

            if shouldResume && wasPlayingBeforeInterruption {
                reactivateAudioSessionIfNeeded()
                player.play()
                isPlaying = true
                print("✅ PlayerViewModel: Resumed after interruption")
            }

            updateNowPlayingPlaybackInfo(force: true)
            updateRemoteCommandState()
            wasPlayingBeforeInterruption = false

        @unknown default:
            break
        }
    }

    private func handleAudioRouteChange(reasonValue: UInt?) {
        guard let reasonValue,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        switch reason {
        case .oldDeviceUnavailable:
            if isPlaying {
                player.pause()
                isPlaying = false
                updateNowPlayingPlaybackInfo(force: true)
                updateRemoteCommandState()
                print("⚠️ PlayerViewModel: Paused because audio route became unavailable")
            }
        case .newDeviceAvailable:
            if isPlaying {
                reactivateAudioSessionIfNeeded()
                player.play()
            }
        case .routeConfigurationChange:
            reactivateAudioSessionIfNeeded()
        default:
            break
        }
    }

    private func reactivateAudioSessionIfNeeded() {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("⚠️ PlayerViewModel: Failed to reactivate audio session: \(error)")
        }
    }
    #else
    private func setupAudioLifecycleObservers() {}
    private func reactivateAudioSessionIfNeeded() {}
    #endif

    // MARK: - Internal Setup

    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            Task { @MainActor in
                let previousDuration = self.duration
                self.currentTime = max(time.seconds, 0)
                if let duration = self.player.currentItem?.duration.seconds, !duration.isNaN {
                    self.duration = duration
                }
                if abs(self.duration - previousDuration) > 0.5 {
                    self.updateNowPlayingPlaybackInfo(force: true)
                }
            }
        }
    }

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

        updateRemoteCommandState()
    }

    private func play() {
        guard !isPlaying else {
            updateRemoteCommandState()
            return
        }

        reactivateAudioSessionIfNeeded()
        player.play()
        isPlaying = true
        updateNowPlayingPlaybackInfo(force: true)
        updateRemoteCommandState()
    }

    private func pause() {
        guard isPlaying else {
            updateRemoteCommandState()
            return
        }

        player.pause()
        isPlaying = false
        updateNowPlayingPlaybackInfo(force: true)
        updateRemoteCommandState()
    }

    private func updateRemoteCommandState() {
        remoteCommandCenter.playCommand.isEnabled = !isPlaying && currentVideoId != nil
        remoteCommandCenter.pauseCommand.isEnabled = isPlaying
        remoteCommandCenter.togglePlayPauseCommand.isEnabled = currentVideoId != nil
        remoteCommandCenter.changePlaybackPositionCommand.isEnabled = currentVideoId != nil
        remoteCommandCenter.nextTrackCommand.isEnabled = false
        remoteCommandCenter.previousTrackCommand.isEnabled = false
    }

    // MARK: - Now Playing Info

    #if os(iOS)
    private func updateNowPlayingMetadata(force: Bool = true) {
        nowPlayingState.mediaID = currentVideoId
        nowPlayingState.title = currentTitle
        nowPlayingState.artist = currentArtist
        nowPlayingState.artworkURL = currentImageURL
        updateNowPlayingPlaybackInfo(force: force)
    }

    private func updateNowPlayingPlaybackInfo(force: Bool = false) {
        nowPlayingState.elapsedTime = currentElapsedTimeSnapshot()
        nowPlayingState.duration = currentDurationSnapshot()
        nowPlayingState.playbackRate = currentPlaybackRateSnapshot()

        publishNowPlayingInfo(force: force)
    }

    private func publishNowPlayingInfo(force: Bool) {
        guard force || nowPlayingState != lastPublishedNowPlayingState else {
            return
        }

        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: nowPlayingState.title,
            MPMediaItemPropertyArtist: nowPlayingState.artist,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: nowPlayingState.elapsedTime,
            MPNowPlayingInfoPropertyPlaybackRate: nowPlayingState.playbackRate
        ]

        if nowPlayingState.duration > 0 {
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = nowPlayingState.duration
        }

        if currentArtworkMediaID == nowPlayingState.mediaID,
           let currentArtworkResource,
           let mediaArtwork = Self.makeMediaItemArtwork(from: currentArtworkResource) {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = mediaArtwork
        }

        if #available(iOS 26.0, *),
           let mediaID = nowPlayingState.mediaID,
           let animatedArtworkVideoURL,
           currentVideoId == mediaID,
           let animatedArtwork = Self.makeAnimatedArtwork(
                mediaID: mediaID,
                videoURL: animatedArtworkVideoURL,
                previewData: currentArtworkMediaID == mediaID ? currentArtworkResource?.data : nil
           ) {
            let supportedKeys = MPNowPlayingInfoCenter.supportedAnimatedArtworkKeys
            if supportedKeys.contains(MPNowPlayingInfoProperty1x1AnimatedArtwork) {
                nowPlayingInfo[MPNowPlayingInfoProperty1x1AnimatedArtwork] = animatedArtwork
            }
            if supportedKeys.contains(MPNowPlayingInfoProperty3x4AnimatedArtwork) {
                nowPlayingInfo[MPNowPlayingInfoProperty3x4AnimatedArtwork] = animatedArtwork
            }
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        lastPublishedNowPlayingState = nowPlayingState
    }

    private func currentElapsedTimeSnapshot() -> Double {
        let playerTime = player.currentTime().seconds
        if playerTime.isFinite && !playerTime.isNaN && playerTime >= 0 {
            return playerTime
        }

        return max(currentTime, 0)
    }

    private func currentDurationSnapshot() -> Double {
        if duration.isFinite && !duration.isNaN && duration > 0 {
            return duration
        }

        if let itemDuration = player.currentItem?.duration.seconds,
           itemDuration.isFinite,
           !itemDuration.isNaN,
           itemDuration > 0 {
            return itemDuration
        }

        return 0
    }

    private func currentPlaybackRateSnapshot() -> Float {
        guard isPlaying else { return 0 }
        return player.rate > 0 ? player.rate : 1
    }

    private func applyCachedArtworkIfAvailable(for mediaID: String) {
        guard let cachedArtwork = artworkCache[mediaID] else {
            currentArtworkResource = nil
            currentArtworkMediaID = nil
            return
        }

        applyArtwork(cachedArtwork, for: mediaID, cacheInMemory: false)
    }

    private func applyArtwork(
        _ artwork: CachedNowPlayingArtworkResource,
        for mediaID: String,
        cacheInMemory: Bool
    ) {
        currentImageURL = artwork.url
        currentArtworkResource = artwork
        currentArtworkMediaID = mediaID

        if cacheInMemory {
            artworkCache[mediaID] = artwork
        }
    }

    private func loadPersistentArtworkIfAvailable(for mediaID: String) async -> CachedNowPlayingArtworkResource? {
        guard let mediaCacheStore,
              let cachedArtwork = await mediaCacheStore.cachedLocalArtworkData(for: mediaID),
              let image = UIImage(data: cachedArtwork.data) else {
            return nil
        }

        return CachedNowPlayingArtworkResource(
            url: cachedArtwork.url,
            data: cachedArtwork.data,
            size: image.size
        )
    }

    private func persistArtwork(_ artwork: CachedNowPlayingArtworkResource, mediaID: String) async {
        guard let mediaCacheStore else { return }
        _ = await mediaCacheStore.saveArtworkData(
            artwork.data,
            mediaID: mediaID,
            sourceURL: artwork.url
        )
    }

    private func loadNowPlayingArtwork(for mediaID: String, title: String, artist: String, fallbackURL: URL?) {
        artworkLoadTask?.cancel()

        let artworkTitle = title
        let artworkArtist = artist
        let fallbackArtworkURL = fallbackURL

        artworkLoadTask = Task { [weak self, itunes] in
            guard let self else { return }
            if Task.isCancelled { return }

            if let persistedArtwork = await self.loadPersistentArtworkIfAvailable(for: mediaID) {
                guard self.currentVideoId == mediaID else { return }
                self.applyArtwork(persistedArtwork, for: mediaID, cacheInMemory: true)
                self.updateNowPlayingMetadata(force: true)
                return
            }

            let fallbackTask = Task {
                await Self.fetchArtworkResource(from: fallbackArtworkURL)
            }
            let highQualityTask = Task<CachedNowPlayingArtworkResource?, Never> {
                if let cachedURL = self.mediaCacheStore?.cachedHighQualityArtworkURL(
                    for: mediaID,
                    maxAge: CachePolicy.highQualityArtworkTTL
                ) {
                    if let cachedArtwork = await Self.fetchArtworkResource(from: cachedURL) {
                        return cachedArtwork
                    }
                }

                if let highQualityURL = await Self.resolveHighQualityArtworkURL(
                    using: itunes,
                    title: artworkTitle,
                    artist: artworkArtist
                ) {
                    self.mediaCacheStore?.saveHighQualityArtworkURL(highQualityURL, for: mediaID)
                    return await Self.fetchArtworkResource(from: highQualityURL)
                }

                return nil
            }

            if let fallbackArtwork = await fallbackTask.value {
                guard self.currentVideoId == mediaID else { return }
                guard self.currentArtworkMediaID != mediaID else { return }

                self.applyArtwork(fallbackArtwork, for: mediaID, cacheInMemory: false)
                self.updateNowPlayingMetadata(force: true)
                await self.persistArtwork(fallbackArtwork, mediaID: mediaID)
            }

            if let highQualityArtwork = await highQualityTask.value {
                guard self.currentVideoId == mediaID else { return }

                self.applyArtwork(highQualityArtwork, for: mediaID, cacheInMemory: true)
                self.updateNowPlayingMetadata(force: true)
                await self.persistArtwork(highQualityArtwork, mediaID: mediaID)
            }
        }
    }

    nonisolated private static func resolveHighQualityArtworkURL(using itunes: iTunesKit, title: String, artist: String) async -> URL? {
        do {
            let response = try await itunes.search(term: "\(title) \(artist)", country: "us", media: "music", limit: 1)
            return normalizedITunesArtworkURL(from: response.results.first?.artworkUrl100)
        } catch {
            return nil
        }
    }

    private func resolveMotionArtworkURL(for mediaID: String, title: String, artist: String) async -> URL? {
        if let cachedURL = mediaCacheStore?.cachedMotionArtworkSourceURL(
            for: mediaID,
            maxAge: CachePolicy.motionArtworkSourceTTL
        ) {
            return cachedURL
        }

        guard let resolvedURL = await Self.resolveMotionArtworkURL(
            using: itunes,
            title: title,
            artist: artist
        ) else {
            return nil
        }

        mediaCacheStore?.saveMotionArtworkSourceURL(resolvedURL, for: mediaID)
        return resolvedURL
    }

    nonisolated private static func resolveMotionArtworkURL(using itunes: iTunesKit, title: String, artist: String) async -> URL? {
        do {
            let response = try await itunes.search(term: "\(title) \(artist)", country: "us", media: "music", limit: 1)
            guard let trackId = response.results.first?.trackId else {
                return nil
            }

            let webClient = iTunesWebServiceClient()
            let catalogService = WebCatalogService(client: webClient)
            let catalogResponse = try await catalogService.fetchSongDetails(songId: String(trackId))
            return firstMotionArtworkURL(from: catalogResponse)
        } catch {
            return nil
        }
    }

    nonisolated private static func firstMotionArtworkURL(from response: iTunesCatalogResponse) -> URL? {
        for album in response.resources.albums.values {
            let editorialVideo = album.attributes.editorialVideo
            if let url = motionArtworkURL(from: editorialVideo.motionDetailTall.video) {
                return url
            }
            if let url = motionArtworkURL(from: editorialVideo.motionTallVideo3X4.video) {
                return url
            }
            if let url = motionArtworkURL(from: editorialVideo.motionDetailSquare.video) {
                return url
            }
            if let url = motionArtworkURL(from: editorialVideo.motionSquareVideo1X1.video) {
                return url
            }
        }

        return nil
    }

    nonisolated private static func motionArtworkURL(from string: String) -> URL? {
        URL(string: string)
    }

    nonisolated private static func fetchArtworkResource(from url: URL?) async -> CachedNowPlayingArtworkResource? {
        guard let url else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else { return nil }
            return CachedNowPlayingArtworkResource(url: url, data: data, size: image.size)
        } catch {
            return nil
        }
    }

    nonisolated private static func makeMediaItemArtwork(from resource: CachedNowPlayingArtworkResource) -> MPMediaItemArtwork? {
        let imageData = resource.data
        let boundsSize = resource.size

        return MPMediaItemArtwork(boundsSize: boundsSize) { _ in
            UIImage(data: imageData) ?? UIImage()
        }
    }

    @available(iOS 26.0, *)
    nonisolated private static func makeAnimatedArtwork(
        mediaID: String,
        videoURL: URL,
        previewData: Data?
    ) -> MPMediaItemAnimatedArtwork? {
        guard videoURL.isFileURL else {
            return nil
        }

        let artworkID = "\(mediaID)-\(videoURL.lastPathComponent)"
        return MPMediaItemAnimatedArtwork(
            artworkID: artworkID,
            previewImageRequestHandler: { requestedSize in
                guard let previewData,
                      let image = UIImage(data: previewData) else {
                    return nil
                }

                return makeAnimatedArtworkPreviewImage(
                    from: image,
                    requestedSize: requestedSize
                )
            },
            videoAssetFileURLRequestHandler: { _ in
                videoURL
            }
        )
    }

    @available(iOS 26.0, *)
    nonisolated private static func makeAnimatedArtworkPreviewImage(
        from image: UIImage,
        requestedSize: CGSize
    ) -> UIImage {
        let targetSize = normalizedAnimatedArtworkPreviewSize(
            requestedSize,
            fallbackSize: image.size
        )

        guard targetSize.width > 0,
              targetSize.height > 0,
              image.size.width > 0,
              image.size.height > 0 else {
            return image
        }

        let sourceAspectRatio = image.size.width / image.size.height
        let targetAspectRatio = targetSize.width / targetSize.height

        let drawRect: CGRect
        if sourceAspectRatio > targetAspectRatio {
            let scaledHeight = targetSize.height
            let scaledWidth = scaledHeight * sourceAspectRatio
            drawRect = CGRect(
                x: (targetSize.width - scaledWidth) / 2,
                y: 0,
                width: scaledWidth,
                height: scaledHeight
            )
        } else {
            let scaledWidth = targetSize.width
            let scaledHeight = scaledWidth / sourceAspectRatio
            drawRect = CGRect(
                x: 0,
                y: (targetSize.height - scaledHeight) / 2,
                width: scaledWidth,
                height: scaledHeight
            )
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale > 0 ? image.scale : 1

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            image.draw(in: drawRect)
        }
    }

    @available(iOS 26.0, *)
    nonisolated private static func normalizedAnimatedArtworkPreviewSize(
        _ requestedSize: CGSize,
        fallbackSize: CGSize
    ) -> CGSize {
        if requestedSize.width > 0,
           requestedSize.height > 0,
           requestedSize.width.isFinite,
           requestedSize.height.isFinite {
            return requestedSize
        }

        if fallbackSize.width > 0,
           fallbackSize.height > 0,
           fallbackSize.width.isFinite,
           fallbackSize.height.isFinite {
            return fallbackSize
        }

        return CGSize(width: 512, height: 512)
    }
    #else
    private func updateNowPlayingMetadata(force: Bool = true) {}
    private func updateNowPlayingPlaybackInfo(force: Bool = false) {}
    private func publishNowPlayingInfo(force: Bool) {}
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
