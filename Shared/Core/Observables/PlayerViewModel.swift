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
    private var currentItemStatusObservation: NSKeyValueObservation?
    private let metadataCache = VideoMetadataCache.shared
    private let settings: PrefetchSettings
    
    init(youtube: YouTube = .shared, settings: PrefetchSettings = .shared) {
        // Create or use shared AVPlayer at the view model level
        self.youtube = youtube
        self.settings = settings
        self.player = AVPlayer()
        configureAudioSession()
        setupRemoteCommands()
        setupTimeObserver()
    }
    
    // MARK: - Loaders
    
    func load(song: YouTubeMusicSong) {
        let tapStartedAt = Date()
        // 1. Set Metadata immediately (for instant UI feedback)
        self.currentTitle = song.title
        self.currentArtist = song.artistsDisplay
        self.currentImageURL = song.thumbnailURL
        self.isExplicit = song.isExplicit
        self.currentVideoId = song.videoId

        #if os(iOS)
        cachedStaticArtworkImage = nil
        cachedPreviewImage = nil
        currentMotionVideoRemoteURL = nil

        self.launchAnimatedArtworkRefresh(title: song.title, artist: song.artistsDisplay)

        Task { [title = song.title, artist = song.artistsDisplay, fallbackURL = song.thumbnailURL, expectedVideoId = song.videoId] in
            await self.resolveHighQualityArtwork(
                title: title,
                artist: artist,
                fallbackURL: fallbackURL,
                expectedVideoId: expectedVideoId
            )
        }
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
        self.currentTitle = video.title
        self.currentArtist = video.author
        self.currentImageURL = URL(string: video.thumbnailURL ?? "")
        self.isExplicit = false
        self.currentVideoId = video.id

        #if os(iOS)
        cachedStaticArtworkImage = nil
        cachedPreviewImage = nil
        currentMotionVideoRemoteURL = nil

        self.launchAnimatedArtworkRefresh(title: video.title, artist: video.author)

        Task { [title = video.title, artist = video.author, fallbackURL = URL(string: video.thumbnailURL ?? ""), expectedVideoId = video.id] in
            await self.resolveHighQualityArtwork(
                title: title,
                artist: artist,
                fallbackURL: fallbackURL,
                expectedVideoId: expectedVideoId
            )
        }
        #endif
        
        currentLoadTask?.cancel()
        currentLoadTask = Task {
            if Task.isCancelled { return }
            
            do {
                let resolvedURL = try await self.resolvePlaybackURL(forID: video.id, fallbackVideo: video)
                
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
    
    // MARK: - Internal Setup
    
    private func setupTimeObserver() {
        // Observe the stable player instance once
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            Task { @MainActor in
                self.currentTime = time.seconds
                if let duration = self.player.currentItem?.duration.seconds, !duration.isNaN {
                    self.duration = duration
                }
                // Keep now playing elapsed time in sync
                self.updateNowPlayingPlaybackInfo()
            }
        }
    }
    
    // MARK: - Remote Commands
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

    private func resolvePlaybackURL(forID id: String, fallbackVideo: YouTubeVideo? = nil) async throws -> URL {
        do {
            let entry = try await metadataCache.resolve(id: id, metricsEnabled: settings.metricsEnabled) { key in
                try await self.youtube.main.video(id: key)
            }
            return entry.resolvedURL
        } catch {
            print("⚠️ PlayerViewModel: First resolve failed for id=\(id): \(error.localizedDescription). Retrying once...")

            try? await Task.sleep(nanoseconds: 350_000_000)

            do {
                let retryEntry = try await metadataCache.resolve(id: id, metricsEnabled: settings.metricsEnabled) { key in
                    try await self.youtube.main.video(id: key)
                }
                return retryEntry.resolvedURL
            } catch {
                if let fallbackVideo,
                   let fallbackURL = Self.resolvePlayableURL(from: fallbackVideo) {
                    print("✅ PlayerViewModel: Using direct video stream fallback for id=\(id)")
                    return fallbackURL
                }

                throw error
            }
        }
    }

    nonisolated private static func extractPlayableURL(fromPlayerResponse playerResponse: [String: Any]) -> URL? {
        guard let streamingData = playerResponse["streamingData"] as? [String: Any] else { return nil }

        if let hlsString = streamingData["hlsManifestUrl"] as? String,
           let hlsURL = URL(string: hlsString) {
            return hlsURL
        }

        let formats = (streamingData["formats"] as? [[String: Any]] ?? []) + (streamingData["adaptiveFormats"] as? [[String: Any]] ?? [])

        for stream in formats {
            if let urlString = stream["url"] as? String,
               let url = URL(string: urlString) {
                return url
            }
        }

        return nil
    }

    nonisolated private static func resolvePlayableURL(from video: YouTubeVideo) -> URL? {
        if let hls = video.hlsURL {
            return hls
        }
        if let stream = video.bestMuxedStream ?? video.bestAudioStream,
           let urlString = stream.url,
           let url = URL(string: urlString) {
            return url
        }
        return nil
    }
    
    private func playFromBeginning(url: URL) {
        let item = AVPlayerItem(url: url)
        observeCurrentItemStatus(item)
        player.replaceCurrentItem(with: item)
        seek(to: .zero)
        currentTime = 0
        duration = 0
        isPlaying = true
        player.play()
        
        // Initial metadata update
        updateNowPlayingMetadata()
    }
    
    // MARK: - Now Playing Info (cross-platform)
    
    /// Updates the full metadata (title, artist, duration). Called once when a track loads.
    private func updateNowPlayingMetadata() {
        var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        nowPlayingInfo[MPMediaItemPropertyTitle] = currentTitle
        nowPlayingInfo[MPMediaItemPropertyArtist] = currentArtist
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = player.rate
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentTime().seconds
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = player.currentItem?.duration.seconds ?? 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    /// Updates just the playback state (elapsed time, rate). Called periodically by the time observer.
    private func updateNowPlayingPlaybackInfo() {
        guard var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = player.rate
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentTime().seconds
        if let d = player.currentItem?.duration.seconds, !d.isNaN {
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = d
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
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
    
    // MARK: - iOS 26 Animated Artwork
    #if os(iOS)
    
    /// Cached static album artwork resolved from iTunes.
    private var cachedStaticArtworkImage: UIImage?
    /// Cached preview image for the current animated artwork (3:4 editorial preview from Apple Music)
    private var cachedPreviewImage: UIImage?
    /// Remote motion video URL for the current track
    private var currentMotionVideoRemoteURL: URL?
    /// Cached local file URL for the exported animated artwork video.
    private var cachedAnimatedArtworkVideoURL: URL?
    
    /// Holds both the video and preview frame URLs from the editorial video
    private struct MotionVideoInfo {
        let videoURL: URL
        let previewFrameURL: URL
    }

    private func launchAnimatedArtworkRefresh(title: String, artist: String) {
        Task(priority: .utility) { [weak self] in
            guard let self else { return }
            await self.fetchAndSetAnimatedArtwork(title: title, artist: artist)
        }
    }
    
    private func fetchAndSetAnimatedArtwork(title: String, artist: String) async {
        // 1. Fetch the remote motion video + preview frame URLs from iTunesKit
        guard let info = await fetchMotionVideoInfo(title: title, artist: artist) else { return }
        self.currentMotionVideoRemoteURL = info.videoURL
        print("🎞️ PlayerViewModel: Motion video found for \(title) — \(info.videoURL.absoluteString)")
        
        // 2. Pre-fetch the EDITORIAL preview image (correct 3:4 aspect ratio)
        cachedPreviewImage = await downloadPreviewImage(from: info.previewFrameURL)

        // 3. Pre-export a local file before MediaPlayer asks for it.
        cachedAnimatedArtworkVideoURL = await exportAnimatedArtworkVideo(from: info.videoURL, artworkID: currentVideoId ?? UUID().uuidString)
        
        // 4. Update now playing info with animated artwork
        updateNowPlayingInfo()
    }
    
    private func fetchMotionVideoInfo(title: String, artist: String) async -> MotionVideoInfo? {
        let kit = iTunesKit()
        do {
            let term = "\(title) \(artist)"
            let results = try await kit.searchSongs(term: term)
            guard let trackId = results.first?.trackId else { return nil }
            
            let tokenService = iTunesWebTokenService()
            let webClient = iTunesWebServiceClient(tokenService: tokenService)
            let catalogService = WebCatalogService(client: webClient)
            
            let songId = String(trackId)
            let response = try await catalogService.fetchSongDetails(songId: songId)
            
            if let song = response.resources.songs[songId],
               let albumId = song.relationships?.albums.data.first?.id,
               let album = response.resources.albums[albumId] {
                let motionVideo = album.attributes.editorialVideo.motionDetailTall
                guard let videoURL = URL(string: motionVideo.video),
                      let previewURL = Self.normalizedMotionPreviewURL(
                        from: motionVideo.previewFrame.url,
                        width: motionVideo.previewFrame.width,
                        height: motionVideo.previewFrame.height
                      ) else { return nil }
                return MotionVideoInfo(videoURL: videoURL, previewFrameURL: previewURL)
            }
        } catch {
            print("❌ PlayerViewModel: Failed to fetch motion video: \(error)")
        }
        return nil
    }

    private func resolveHighQualityArtwork(title: String, artist: String, fallbackURL: URL?, expectedVideoId: String) async {
        let highResURL = await fetchHighQualityArtworkURL(title: title, artist: artist)
        let preferredURL = highResURL ?? fallbackURL
        guard let preferredURL else {
            print("⚠️ PlayerViewModel: No artwork URL available for id=\(expectedVideoId)")
            return
        }

        guard currentVideoId == expectedVideoId else {
            print("ℹ️ PlayerViewModel: Ignoring stale artwork response for id=\(expectedVideoId)")
            return
        }

        self.currentImageURL = preferredURL
        if highResURL != nil {
            print("🖼️ PlayerViewModel: Using high-res iTunes artwork URL \(preferredURL.absoluteString)")
        } else {
            print("🖼️ PlayerViewModel: Falling back to thumbnail URL \(preferredURL.absoluteString)")
        }

        guard let artworkImage = await downloadImage(from: preferredURL) else { return }
        self.cachedStaticArtworkImage = artworkImage
        self.updateNowPlayingArtwork()
    }

    private func fetchHighQualityArtworkURL(title: String, artist: String) async -> URL? {
        let kit = iTunesKit()
        let searchTerms = [
            "\(title) \(artist)".trimmingCharacters(in: .whitespacesAndNewlines),
            title.trimmingCharacters(in: .whitespacesAndNewlines),
            "\(artist) \(title)".trimmingCharacters(in: .whitespacesAndNewlines)
        ].filter { !$0.isEmpty }

        for term in searchTerms {
            do {
                let results = try await kit.searchSongs(term: term)
                if let artworkURLString = results.first(where: { $0.artworkUrl100 != nil })?.artworkUrl100,
                   let url = Self.normalizedAlbumArtworkURL(from: artworkURLString) {
                    print("✅ PlayerViewModel: Found high-res iTunes artwork via term='\(term)'")
                    return url
                }
                print("⚠️ PlayerViewModel: No artwork candidates for term='\(term)'")
            } catch {
                print("⚠️ PlayerViewModel: iTunes artwork search failed for term='\(term)': \(error)")
            }
        }

        return nil
    }

    private func downloadImage(from url: URL) async -> UIImage? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch {
            print("⚠️ PlayerViewModel: Failed to download artwork image: \(error)")
            return nil
        }
    }
    
    private func downloadPreviewImage(from url: URL) async -> UIImage? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch {
            print("❌ PlayerViewModel: Failed to download preview image: \(error)")
            return nil
        }
    }
    
    
    private func exportAnimatedArtworkVideo(from remoteURL: URL, artworkID: String) async -> URL? {
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("cisum_artwork_\(artworkID).mov")

        if FileManager.default.fileExists(atPath: destination.path) {
            return destination
        }

        let asset = AVURLAsset(url: remoteURL)
        let presets = [AVAssetExportPresetPassthrough, AVAssetExportPresetMediumQuality]

        for preset in presets {
            guard let exportSession = AVAssetExportSession(asset: asset, presetName: preset) else { continue }

            try? FileManager.default.removeItem(at: destination)
            exportSession.outputURL = destination
            exportSession.outputFileType = .mov
            exportSession.timeRange = CMTimeRange(start: .zero, duration: CMTime(seconds: 30, preferredTimescale: 600))

            await exportSession.export()

            if exportSession.status == .completed {
                print("✅ PlayerViewModel: Exported animated artwork video with preset: \(preset)")
                return destination
            } else {
                print("⚠️ PlayerViewModel: Export with \(preset) failed: \(exportSession.error?.localizedDescription ?? "unknown")")
                try? FileManager.default.removeItem(at: destination)
            }
        }

        print("❌ PlayerViewModel: Animated artwork export failed")
        return nil
    }

    /// Adds artwork and animated artwork to the existing now playing info. iOS only.
    private func updateNowPlayingInfo() {
        var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        
        // Static artwork — built via nonisolated factory to avoid @MainActor closure isolation
        if let staticImage = cachedStaticArtworkImage ?? cachedPreviewImage {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = Self.makeStaticArtwork(image: staticImage)
        }
        
        if #available(iOS 26.0, *) {
            if let videoURL = cachedAnimatedArtworkVideoURL {
                let supportedKeys = MPNowPlayingInfoCenter.supportedAnimatedArtworkKeys
                let artworkID = currentVideoId ?? UUID().uuidString
                
                if supportedKeys.contains(MPNowPlayingInfoProperty3x4AnimatedArtwork) {
                    let tallArtwork = Self.makeAnimatedArtwork(
                        artworkID: artworkID,
                        previewImage: cachedPreviewImage,
                        videoURL: videoURL
                    )
                    nowPlayingInfo[MPNowPlayingInfoProperty3x4AnimatedArtwork] = tallArtwork
                }
            }
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    private func updateNowPlayingArtwork() {
        updateNowPlayingInfo()
    }
    
    // MARK: - Nonisolated Artwork Factories
    // These MUST be nonisolated to prevent closures from inheriting @MainActor isolation.
    // MPNowPlayingInfoCenter calls these closures on its own background queue.
    
    nonisolated private static func makeStaticArtwork(image: UIImage) -> MPMediaItemArtwork {
        MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }

    nonisolated private static func normalizedAlbumArtworkURL(from artworkURLString: String?) -> URL? {
        guard let artworkURLString else { return nil }

        let decoded = artworkURLString.removingPercentEncoding ?? artworkURLString
        let candidates = [
            decoded.replacingOccurrences(of: "100x100", with: "1500x1500"),
            decoded.replacingOccurrences(of: "100bb", with: "1500bb"),
            decoded.replacingOccurrences(of: "{w}x{h}bb.{f}", with: "1500x1500bb.jpg"),
            decoded.replacingOccurrences(of: "%7Bw%7Dx%7Bh%7Dbb.%7Bf%7D", with: "1500x1500bb.jpg")
        ]

        for candidate in candidates where candidate != decoded {
            if let url = URL(string: candidate) {
                return url
            }
        }

        return URL(string: decoded)
    }

    nonisolated private static func normalizedMotionPreviewURL(from urlString: String, width: Int, height: Int) -> URL? {
        let decoded = urlString.removingPercentEncoding ?? urlString
        let dimensionString = "\(width)x\(height)"
        let candidates = [
            decoded.replacingOccurrences(of: "{w}x{h}bb.{f}", with: "\(dimensionString)bb.jpg"),
            decoded.replacingOccurrences(of: "%7Bw%7Dx%7Bh%7Dbb.%7Bf%7D", with: "\(dimensionString)bb.jpg"),
            decoded.replacingOccurrences(of: "{w}x{h}", with: dimensionString),
            decoded.replacingOccurrences(of: "{f}", with: "jpg")
        ]

        for candidate in candidates {
            if let url = URL(string: candidate) {
                return url
            }
        }

        return nil
    }
    
    @available(iOS 26.0, *)
    nonisolated private static func makeAnimatedArtwork(
        artworkID: String,
        previewImage: UIImage?,
        videoURL: URL
    ) -> MPMediaItemAnimatedArtwork {
        MPMediaItemAnimatedArtwork(
            artworkID: artworkID,
            previewImageRequestHandler: { _ in
                return previewImage
            },
            videoAssetFileURLRequestHandler: { _ in
                return videoURL
            }
        )
    }
    #endif
}
