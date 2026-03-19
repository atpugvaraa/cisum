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
    private let metadataCache = VideoMetadataCache.shared
    private let settings: PrefetchSettings
    
    init(youtube: YouTube = .shared, settings: PrefetchSettings = .shared) {
        // Create or use shared AVPlayer at the view model level
        self.youtube = youtube
        self.settings = settings
        self.player = AVPlayer()
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
        
        currentLoadTask?.cancel()
        currentLoadTask = Task {
            if Task.isCancelled { return }
            
            do {
                let entry = try await metadataCache.resolve(id: song.videoId, metricsEnabled: settings.metricsEnabled) { id in
                    try await self.youtube.main.video(id: id)
                }
                
                if Task.isCancelled { return }
                
                self.playFromBeginning(url: entry.resolvedURL)
                
                if settings.metricsEnabled {
                    let elapsed = Date().timeIntervalSince(tapStartedAt) * 1000
                    await PlaybackMetricsStore.shared.recordTapToPlay(durationMs: elapsed)
                }
            } catch {
                togglePlayPause()
                self.playbackError = error.localizedDescription
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
        
        currentLoadTask?.cancel()
        currentLoadTask = Task {
            if Task.isCancelled { return }
            
            do {
                let entry = try await metadataCache.resolve(id: video.id, metricsEnabled: settings.metricsEnabled) { id in
                    try await self.youtube.main.video(id: id)
                }
                
                if Task.isCancelled { return }
                
                self.playFromBeginning(url: entry.resolvedURL)
                
                if settings.metricsEnabled {
                    let elapsed = Date().timeIntervalSince(tapStartedAt) * 1000
                    togglePlayPause()
                    await PlaybackMetricsStore.shared.recordTapToPlay(durationMs: elapsed)
                }
            } catch {
                togglePlayPause()
                self.playbackError = error.localizedDescription
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
    }
    
    func seek(to seconds: Double) {
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: time)
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
            }
        }
    }
    
    // MARK: - Lock Screen Controls (Bonus)
    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
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
                let entry = try await metadataCache.resolve(id: id, metricsEnabled: settings.metricsEnabled) { key in
                    try await self.youtube.main.video(id: key)
                }
                
                if Task.isCancelled { return }
                
                self.playFromBeginning(url: entry.resolvedURL)
            } catch {
                self.playbackError = error.localizedDescription
            }
        }
    }
    
    private func playFromBeginning(url: URL) {
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        seek(to: .zero)
        currentTime = 0
        duration = 0
        togglePlayPause()
    }
}
