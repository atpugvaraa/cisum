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
    private var artworkLoadTask: Task<Void, Never>?
    private var currentItemStatusObservation: NSKeyValueObservation?
    private let remoteCommandCenter = MPRemoteCommandCenter.shared()
    private let metadataCache = VideoMetadataCache.shared
    private let itunes = iTunesKit()
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
        currentTime = 0
        duration = 0
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
        currentTime = 0
        duration = 0
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
        updateRemoteCommandState()
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
                    self.updateNowPlayingPlaybackInfo(force: true)
                    self.updateRemoteCommandState()
                case .failed:
                    print("❌ PlayerViewModel: AVPlayerItem failed: \(item.error?.localizedDescription ?? "unknown error")")
                    self.isPlaying = false
                    self.playbackError = item.error?.localizedDescription ?? "Failed to load media"
                    self.updateNowPlayingPlaybackInfo(force: true)
                    self.updateRemoteCommandState()
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

        currentImageURL = cachedArtwork.url
        currentArtworkResource = cachedArtwork
        currentArtworkMediaID = mediaID
    }

    private func loadNowPlayingArtwork(for mediaID: String, title: String, artist: String, fallbackURL: URL?) {
        artworkLoadTask?.cancel()

        let artworkTitle = title
        let artworkArtist = artist
        let fallbackArtworkURL = fallbackURL

        artworkLoadTask = Task { [itunes] in
            if Task.isCancelled { return }

            let fallbackTask = Task {
                await Self.fetchArtworkResource(from: fallbackArtworkURL)
            }
            let highQualityTask = Task<CachedNowPlayingArtworkResource?, Never> {
                if let highQualityURL = await Self.resolveHighQualityArtworkURL(
                    using: itunes,
                    title: artworkTitle,
                    artist: artworkArtist
                ) {
                    return await Self.fetchArtworkResource(from: highQualityURL)
                }

                return nil
            }

            if let fallbackArtwork = await fallbackTask.value {
                await MainActor.run {
                    guard self.currentVideoId == mediaID else { return }
                    guard self.currentArtworkMediaID != mediaID else { return }

                    self.currentImageURL = fallbackArtwork.url
                    self.currentArtworkResource = fallbackArtwork
                    self.currentArtworkMediaID = mediaID
                    self.updateNowPlayingMetadata(force: true)
                }
            }

            if let highQualityArtwork = await highQualityTask.value {
                await MainActor.run {
                    guard self.currentVideoId == mediaID else { return }

                    self.artworkCache[mediaID] = highQualityArtwork
                    self.currentImageURL = highQualityArtwork.url
                    self.currentArtworkResource = highQualityArtwork
                    self.currentArtworkMediaID = mediaID
                    self.updateNowPlayingMetadata(force: true)
                }
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
    #else
    private func updateNowPlayingMetadata(force: Bool = true) {}
    private func updateNowPlayingPlaybackInfo(force: Bool = false) {}
    private func publishNowPlayingInfo(force: Bool) {}
    #endif
}
