import Foundation
import AVFoundation
import Observation
import Models
import Services
import YouTubeSDK
import Utilities

@Observable
@MainActor
public final class PlaybackEngine {
    // MARK: - Core
    public let player: AVPlayer = AVPlayer()
    public private(set) var isPlaying: Bool = false
    public private(set) var currentTime: Double = 0
    public private(set) var duration: Double = 0
    public var volume: Float {
        get { player.volume }
        set { player.volume = newValue }
    }
    
    public var onProgressUpdate: (@MainActor () -> Void)?
    
    // MARK: - Initializer
    public init() {
        setupAudioSession()
        setupPeriodicTimeObserver()
    }
    
    private func setupAudioSession() {
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, policy: .longFormAudio)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
        #endif
    }
    
    private func setupPeriodicTimeObserver() {
        player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.2, preferredTimescale: 600), queue: .main) { [weak self] time in
            guard let self else { return }
            let nextTime = max(time.seconds, 0)
            if abs(self.currentTime - nextTime) > 0.001 {
                self.currentTime = nextTime
            }
            
            if let duration = self.player.currentItem?.duration.seconds, duration.isFinite {
                if abs(self.duration - duration) > 0.001 {
                    self.duration = duration
                }
            }
            
            self.onProgressUpdate?()
        }
    }
    
    // MARK: - Actions
    public func play() {
        player.play()
        isPlaying = true
        #if os(iOS)
        VolumeButtonSkipController.shared.handlePlaybackStateChanged(isPlaying: true)
        #endif
    }
    
    public func pause() {
        player.pause()
        isPlaying = false
        #if os(iOS)
        VolumeButtonSkipController.shared.handlePlaybackStateChanged(isPlaying: false)
        #endif
    }
    
    public func setIsPlaying(_ playing: Bool) {
        self.isPlaying = playing
        #if os(iOS)
        VolumeButtonSkipController.shared.handlePlaybackStateChanged(isPlaying: playing)
        #endif
    }
    
    public func resetProgress() {
        self.currentTime = 0
        self.duration = 0
    }
    
    public func seek(to time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }
    
    public func load(url: URL) {
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        play()
    }
    
    public func reactivateSession() {
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
    }
}
