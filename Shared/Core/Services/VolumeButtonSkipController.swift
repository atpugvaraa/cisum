#if os(iOS)

import Foundation
import SwiftUI
import UIKit

@Observable
@MainActor
final class VolumeButtonSkipController {
    static let shared = VolumeButtonSkipController()

    private enum Tuning {
        static let tickInterval: TimeInterval = 0.03
        static let eventDebounceInterval: TimeInterval = 0.012
        static let valueChangeEpsilon: Float = 0.001
        static let lockEpsilon: Float = 0.004
        static let programmaticEchoWindow: TimeInterval = 0.08
        static let edgeBoundaryEpsilon: Float = 0.0005
        static let edgeReserve: Float = 0.015
        static let fallbackButtonStep: Float = 0.0625
        static let activationSignalRecency: TimeInterval = 0.11
        static let kvoFallbackSuppressionAfterButtonEvent: TimeInterval = 0.03
    }

    private enum Direction {
        case up
        case down
    }

    private enum HapticEvent {
        case activated
        case repeatedSkip
    }

    private struct HoldSession {
        var direction: Direction
        var baselineVolume: Float
        var startedAt: Date
        var lastHardwareEventAt: Date
        var lastAcceptedEventAt: Date
        var lastSkipAt: Date?
        var activated: Bool
    }

    private let settings: PlaybackControlSettings
    private weak var playerViewModel: PlayerViewModel?
    private weak var volumeController: SystemVolumeController?

    private var session: HoldSession?
    private var pollingTimer: Timer?
    private var suppressProgrammaticEventsUntil: Date = .distantPast
    private var expectedProgrammaticVolume: Float?
    private var latestObservedVolume: Float = 0
    private var previousObservedVolume: Float = 0
    private var lastButtonEventAt: Date = .distantPast
    private var activationFeedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    private var repeatFeedbackGenerator = UIImpactFeedbackGenerator(style: .light)

    private init(settings: PlaybackControlSettings = .shared) {
        self.settings = settings
    }

    func configure(playerViewModel: PlayerViewModel, volumeController: SystemVolumeController = .shared) {
        self.playerViewModel = playerViewModel
        self.volumeController = volumeController
        self.latestObservedVolume = Float(volumeController.volume)
        self.previousObservedVolume = Float(volumeController.volume)

        volumeController.onSystemVolumeChanged = { [weak self] oldValue, newValue in
            guard let self else { return }
            Task { @MainActor in
                self.handleObservedVolumeChanged(oldValue: oldValue, newValue: newValue)
            }
        }

        volumeController.onSystemVolumeButtonEvent = { [weak self] direction, reportedVolume in
            guard let self else { return }
            Task { @MainActor in
                self.handleVolumeButtonEvent(direction: direction, reportedVolume: reportedVolume)
            }
        }

        prepareHaptics()
        ensureProactiveEdgeReserveIfNeeded()
    }

    func handleScenePhaseChange(_ phase: ScenePhase) {
        guard phase == .active else {
            endSession(restoreVolume: true)
            return
        }

        prepareHaptics()
        ensureProactiveEdgeReserveIfNeeded()
    }

    func handlePlaybackStateChanged(isPlaying: Bool) {
        guard isPlaying else {
            endSession(restoreVolume: true)
            return
        }

        prepareHaptics()
        ensureProactiveEdgeReserveIfNeeded()
    }

    func cancelActiveHold() {
        endSession(restoreVolume: true)
    }

    private func handleObservedVolumeChanged(oldValue: Float, newValue: Float) {
        previousObservedVolume = oldValue
        latestObservedVolume = newValue

        // Prefer explicit hardware button notifications when available.
        if Date().timeIntervalSince(lastButtonEventAt) < Tuning.kvoFallbackSuppressionAfterButtonEvent {
            return
        }

        guard settings.volumeButtonHoldSkipEnabled else {
            endSession(restoreVolume: false)
            return
        }

        guard let playerViewModel, playerViewModel.isPlaying else {
            endSession(restoreVolume: false)
            return
        }

        let delta = abs(newValue - oldValue)
        guard delta > Tuning.valueChangeEpsilon else { return }

        let direction: Direction = newValue > oldValue ? .up : .down
        ingestHardwareEvent(direction: direction, baselineHint: oldValue)
    }

    private func handleVolumeButtonEvent(
        direction: SystemVolumeController.VolumeButtonEventDirection,
        reportedVolume: Float
    ) {
        latestObservedVolume = reportedVolume
        lastButtonEventAt = Date()

        let mappedDirection: Direction
        switch direction {
        case .up:
            mappedDirection = .up
        case .down:
            mappedDirection = .down
        }

        let baselineHint = estimatedBaseline(for: mappedDirection, reportedVolume: reportedVolume)
        ingestHardwareEvent(direction: mappedDirection, baselineHint: baselineHint)
    }

    private func estimatedBaseline(for direction: Direction, reportedVolume: Float) -> Float {
        switch direction {
        case .up where reportedVolume >= 1 - Tuning.edgeBoundaryEpsilon:
            return 1
        case .down where reportedVolume <= Tuning.edgeBoundaryEpsilon:
            return 0
        case .up:
            let fallback = max(0, reportedVolume - Tuning.fallbackButtonStep)
            return min(fallback, previousObservedVolume)
        case .down:
            let fallback = min(1, reportedVolume + Tuning.fallbackButtonStep)
            return max(fallback, previousObservedVolume)
        }
    }

    private func ingestHardwareEvent(direction: Direction, baselineHint: Float?) {
        guard settings.volumeButtonHoldSkipEnabled else {
            endSession(restoreVolume: false)
            return
        }

        guard let playerViewModel, playerViewModel.isPlaying else {
            endSession(restoreVolume: false)
            return
        }

        let now = Date()
        guard !isProgrammaticEchoEvent(newValue: latestObservedVolume, at: now) else { return }

        let baselineVolume = baselineHint ?? latestObservedVolume

        if var session {
            if now.timeIntervalSince(session.lastAcceptedEventAt) < Tuning.eventDebounceInterval {
                return
            }

            let timedOut = now.timeIntervalSince(session.lastHardwareEventAt) > settings.volumeButtonHoldReleaseTimeout
            if timedOut || session.direction != direction {
                self.session = makeSession(direction: direction, baselineVolume: baselineVolume, at: now)
            } else {
                session.lastHardwareEventAt = now
                session.lastAcceptedEventAt = now
                self.session = session
            }
        } else {
            self.session = makeSession(direction: direction, baselineVolume: baselineVolume, at: now)
        }

        startTimerIfNeeded()
        processTick(at: now)
    }

    private func makeSession(direction: Direction, baselineVolume: Float, at now: Date) -> HoldSession {
        HoldSession(
            direction: direction,
            baselineVolume: baselineVolume,
            startedAt: now,
            lastHardwareEventAt: now,
            lastAcceptedEventAt: now,
            lastSkipAt: nil,
            activated: false
        )
    }

    private func isProgrammaticEchoEvent(newValue: Float, at now: Date) -> Bool {
        guard now < suppressProgrammaticEventsUntil else {
            expectedProgrammaticVolume = nil
            return false
        }

        guard let expectedProgrammaticVolume else {
            return false
        }

        return abs(newValue - expectedProgrammaticVolume) <= Tuning.lockEpsilon
    }

    private func startTimerIfNeeded() {
        guard pollingTimer == nil else { return }

        let timer = Timer(timeInterval: Tuning.tickInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.processTick(at: Date())
            }
        }
        pollingTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopTimer() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    private func processTick(at now: Date) {
        guard var session else {
            stopTimer()
            return
        }

        guard settings.volumeButtonHoldSkipEnabled else {
            endSession(restoreVolume: false)
            return
        }

        guard let playerViewModel, playerViewModel.isPlaying else {
            endSession(restoreVolume: true)
            return
        }

        if now.timeIntervalSince(session.lastHardwareEventAt) > settings.volumeButtonHoldReleaseTimeout {
            let restoreVolume = session.activated
            endSession(restoreVolume: restoreVolume)
            if !restoreVolume {
                ensureProactiveEdgeReserveIfNeeded()
            }
            return
        }

        if !session.activated {
            let reachedActivationDelay = now.timeIntervalSince(session.startedAt) >= settings.volumeButtonHoldThreshold
            let hasRecentSignal = now.timeIntervalSince(session.lastHardwareEventAt) <= Tuning.activationSignalRecency

            if reachedActivationDelay && hasRecentSignal {
                guard canSkip(for: session.direction) else {
                    endSession(restoreVolume: false)
                    return
                }

                session.activated = true
                session.lastSkipAt = now
                self.session = session
                triggerSkip(for: session.direction)
                emitHaptic(.activated)
                enforceVolumeLockIfNeeded(targetVolume: lockTarget(for: session), force: true)
            } else {
                self.session = session
            }
            return
        }

        let currentLockTarget = lockTarget(for: session)
        enforceVolumeLockIfNeeded(targetVolume: currentLockTarget, force: false)

        let shouldRepeat = now.timeIntervalSince(session.lastSkipAt ?? .distantPast) >= settings.volumeButtonHoldRepeatInterval
        if shouldRepeat {
            guard canSkip(for: session.direction) else {
                endSession(restoreVolume: false)
                return
            }

            session.lastSkipAt = now
            self.session = session
            triggerSkip(for: session.direction)
            emitHaptic(.repeatedSkip)
            enforceVolumeLockIfNeeded(targetVolume: currentLockTarget, force: true)
        }
    }

    private func lockTarget(for session: HoldSession) -> Float {
        guard session.activated else { return session.baselineVolume }

        switch session.direction {
        case .up where session.baselineVolume >= 1 - Tuning.edgeBoundaryEpsilon:
            return max(0, 1 - Tuning.edgeReserve)
        case .down where session.baselineVolume <= Tuning.edgeBoundaryEpsilon:
            return min(1, Tuning.edgeReserve)
        default:
            return session.baselineVolume
        }
    }

    private func canSkip(for direction: Direction) -> Bool {
        guard let playerViewModel else { return false }

        let skipForward = isForwardDirection(direction)

        return skipForward ? playerViewModel.canSkipForward : playerViewModel.canSkipBackward
    }

    private func triggerSkip(for direction: Direction) {
        guard let playerViewModel else { return }

        let skipForward = isForwardDirection(direction)

        if skipForward {
            playerViewModel.skipToNext()
        } else {
            playerViewModel.skipToPrevious()
        }
    }

    private func isForwardDirection(_ direction: Direction) -> Bool {
        switch direction {
        case .up:
            settings.volumeButtonHoldUpSkipsForward
        case .down:
            !settings.volumeButtonHoldUpSkipsForward
        }
    }

    private func emitHaptic(_ event: HapticEvent) {
        switch event {
        case .activated:
            activationFeedbackGenerator.impactOccurred(intensity: 1)
            activationFeedbackGenerator.prepare()
        case .repeatedSkip:
            repeatFeedbackGenerator.impactOccurred(intensity: 0.9)
            repeatFeedbackGenerator.prepare()
        }
    }

    private func prepareHaptics() {
        activationFeedbackGenerator.prepare()
        repeatFeedbackGenerator.prepare()
    }

    private func enforceVolumeLockIfNeeded(targetVolume: Float, force: Bool) {
        guard settings.volumeButtonHoldRestoreVolume else { return }
        guard let volumeController, !volumeController.isUserDragging else { return }

        let currentVolume = Float(volumeController.volume)
        guard force || abs(currentVolume - targetVolume) > Tuning.lockEpsilon else {
            return
        }

        suppressProgrammaticEventsUntil = Date().addingTimeInterval(Tuning.programmaticEchoWindow)
        expectedProgrammaticVolume = targetVolume
        volumeController.volume = Double(targetVolume)
        volumeController.applyVolumeToSystem()
    }

    private func ensureProactiveEdgeReserveIfNeeded() {
        guard settings.volumeButtonHoldSkipEnabled else { return }
        guard let playerViewModel, playerViewModel.isPlaying else { return }
        guard let volumeController, !volumeController.isUserDragging else { return }
        guard session == nil else { return }

        let currentVolume = Float(volumeController.volume)
        let reserveTarget: Float?

        if currentVolume <= Tuning.edgeBoundaryEpsilon {
            reserveTarget = Tuning.edgeReserve
        } else if currentVolume >= 1 - Tuning.edgeBoundaryEpsilon {
            reserveTarget = 1 - Tuning.edgeReserve
        } else {
            reserveTarget = nil
        }

        guard let reserveTarget else { return }
        suppressProgrammaticEventsUntil = Date().addingTimeInterval(Tuning.programmaticEchoWindow)
        expectedProgrammaticVolume = reserveTarget
        volumeController.volume = Double(reserveTarget)
        volumeController.applyVolumeToSystem()
    }

    private func endSession(restoreVolume: Bool) {
        if restoreVolume,
           let session,
           session.activated {
            enforceVolumeLockIfNeeded(targetVolume: session.baselineVolume, force: true)
        }

        self.session = nil
        stopTimer()

        if !restoreVolume {
            expectedProgrammaticVolume = nil
            suppressProgrammaticEventsUntil = .distantPast
        }
    }

}

#endif
