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

@Observable
@MainActor
final class PlayerViewModel {

    // MARK: - State
    var player: AVPlayer
    private let youtube: YouTube
    var currentVideoId: String?
    var playbackError: String?

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
    private var currentItemStatusObservation: NSKeyValueObservation?
    private let metadataCache = VideoMetadataCache.shared
    private let settings: PrefetchSettings

#if os(iOS)
    private var interruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?
    private var wasPlayingBeforeInterruption = false
#endif

    init(youtube: YouTube = .shared, settings: PrefetchSettings = .shared) {
        self.youtube = youtube
        self.settings = settings
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

        currentLoadTask?.cancel()
        currentLoadTask = Task {
            if Task.isCancelled { return }

            do {
                let resolvedURL = try await self.resolvePlaybackURL(forID: song.videoId)

                if Task.isCancelled { return }

                self.playFromBeginning(url: resolvedURL)
                print("▶️ PlayerViewModel: Started playback for song id=\(song.videoId)")

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

        currentLoadTask?.cancel()
        currentLoadTask = Task {
            if Task.isCancelled { return }

            do {
                let resolvedURL = try await self.resolvePlaybackURL(forID: video.id)

                if Task.isCancelled { return }

                self.playFromBeginning(url: resolvedURL)
                print("▶️ PlayerViewModel: Started playback for video id=\(video.id)")

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
        if player.timeControlStatus == .playing {
            player.pause()
            isPlaying = false
        } else {
            isPlaying = true
            player.play()
        }
        updateNowPlayingPlaybackInfo()
    }

    func seek(to seconds: Double) {
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: time)
    }

    /// Reload the current video with current playback configuration.
    func reloadCurrentVideo() {
        guard let id = currentVideoId else { return }
        currentLoadTask?.cancel()
        currentLoadTask = Task {
            if Task.isCancelled { return }
            do {
                let resolvedURL = try await self.resolvePlaybackURL(forID: id)

                if Task.isCancelled { return }

                self.playFromBeginning(url: resolvedURL)
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

    private func resolvePlaybackURL(forID id: String) async throws -> URL {
        do {
            let entry = try await metadataCache.resolve(id: id, metricsEnabled: settings.metricsEnabled) { key in
                try await self.youtube.main.video(id: key)
            }
            return entry.resolvedURL
        } catch {
            print("⚠️ PlayerViewModel: First resolve failed for id=\(id): \(error.localizedDescription). Retrying once...")
            try? await Task.sleep(nanoseconds: 350_000_000)

            let retryEntry = try await metadataCache.resolve(id: id, metricsEnabled: settings.metricsEnabled) { key in
                try await self.youtube.main.video(id: key)
            }
            return retryEntry.resolvedURL
        }
    }

    private func playFromBeginning(url: URL) {
        let item = AVPlayerItem(url: url)
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
    }

    private func observeCurrentItemStatus(_ item: AVPlayerItem) {
        currentItemStatusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            guard let self = self else { return }

            Task { @MainActor in
                switch item.status {
                case .readyToPlay:
                    print("✅ PlayerViewModel: AVPlayerItem ready to play")
                    if self.isPlaying {
                        self.player.play()
                    }
                    self.updateNowPlayingPlaybackInfo()
                case .failed:
                    print("❌ PlayerViewModel: AVPlayerItem failed: \(item.error?.localizedDescription ?? "unknown error")")
                    self.isPlaying = false
                    self.playbackError = item.error?.localizedDescription ?? "Failed to load media"
                case .unknown:
                    print("⏳ PlayerViewModel: AVPlayerItem status unknown")
                @unknown default:
                    break
                }
            }
        }
    }

    private func handlePlaybackFailure(_ error: Error) {
        player.pause()
        isPlaying = false
        playbackError = error.localizedDescription
        updateNowPlayingPlaybackInfo()
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
            updateNowPlayingPlaybackInfo()
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

            updateNowPlayingPlaybackInfo()
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
                updateNowPlayingPlaybackInfo()
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
    #endif

    // MARK: - Internal Setup

    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            Task { @MainActor in
                self.currentTime = time.seconds
                if let duration = self.player.currentItem?.duration.seconds, !duration.isNaN {
                    self.duration = duration
                }
                self.updateNowPlayingPlaybackInfo()
            }
        }
    }

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayPause() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayPause() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayPause() }
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in self?.seek(to: positionEvent.positionTime) }
            return .success
        }
    }

    // MARK: - Now Playing Info

    private func updateNowPlayingMetadata() {
        var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        nowPlayingInfo[MPMediaItemPropertyTitle] = currentTitle
        nowPlayingInfo[MPMediaItemPropertyArtist] = currentArtist
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = player.rate
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentTime().seconds
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = player.currentItem?.duration.seconds ?? 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    private func updateNowPlayingPlaybackInfo() {
        guard var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = player.rate
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentTime().seconds
        if let d = player.currentItem?.duration.seconds, !d.isNaN {
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = d
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
}
