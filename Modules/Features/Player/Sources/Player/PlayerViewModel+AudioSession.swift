import Foundation
import AVFoundation
import Services

extension PlayerViewModel {
	func configureAudioSession() {
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

	func configurePlayerForBackgroundPlayback() {
		#if os(iOS)
		player.automaticallyWaitsToMinimizeStalling = true
		if #available(iOS 14.0, *) {
			player.audiovisualBackgroundPlaybackPolicy = .continuesIfPossible
		}
		#endif
	}

	#if os(iOS)
	func setupAudioLifecycleObservers() {
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
			VolumeButtonSkipController.shared.cancelActiveHold()
			wasPlayingBeforeInterruption = isPlaying
			player.pause()
			playbackEngine.setIsPlaying(false)
			updateNowPlayingPlaybackInfo(force: true)
			updateRemoteCommandState()
			print("⚠️ PlayerViewModel: Audio interruption began")

		case .ended:
			let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue ?? 0)
			let shouldResume = options.contains(.shouldResume)

			if shouldResume && wasPlayingBeforeInterruption {
				reactivateAudioSessionIfNeeded()
				player.play()
				playbackEngine.setIsPlaying(true)
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
                playbackEngine.setIsPlaying(false)
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

	func reactivateAudioSessionIfNeeded() {
		do {
			try AVAudioSession.sharedInstance().setActive(true)
		} catch {
			print("⚠️ PlayerViewModel: Failed to reactivate audio session: \(error)")
		}
	}
	#else
	func setupAudioLifecycleObservers() {}
	func reactivateAudioSessionIfNeeded() {}
	#endif
}
