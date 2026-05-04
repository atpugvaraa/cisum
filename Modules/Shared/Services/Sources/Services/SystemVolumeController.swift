#if os(iOS)

import SwiftUI
import MediaPlayer
import AVFoundation
import UIKit

/// Single source of truth for system volume.
/// Observes hardware changes via KVO and sets volume through MPVolumeView's UISlider.
@Observable @MainActor
public final class SystemVolumeController {
    public enum VolumeButtonEventDirection {
        case up
        case down
    }

    public static let shared = SystemVolumeController()

    /// The current volume (0.0 – 1.0).
    public var volume: Double = 0.0

    /// Observes normalized volume transitions from hardware buttons and programmatic updates.
    public var onSystemVolumeChanged: ((Float, Float) -> Void)?

    /// Emits inferred hardware button direction events, including boundary presses.
    public var onSystemVolumeButtonEvent: ((VolumeButtonEventDirection, Float) -> Void)?

    /// Whether the user is currently dragging the custom slider.
    public var isUserDragging: Bool = false

    /// Controls whether the backing MPVolumeView is visually hidden.
    public var showsSystemVolumeHUD: Bool = false {
        didSet {
            volumeView.alpha = showsSystemVolumeHUD ? 1.0 : 0.0001
        }
    }

    /// Hidden MPVolumeView used to hijack the system volume UI.
    private let volumeView: MPVolumeView
    private weak var window: UIWindow?
    private var isActivated = false

    private var observation: NSKeyValueObservation?
    private var systemVolumeObserverTokens: [NSObjectProtocol] = []
    private var lastVolumeNotificationSequenceNumber: Int?
    private var inferredComparisonVolume: Float

    private enum ButtonInference {
        static let edgeEpsilon: Float = 0.0005
        static let stepSize: Float = 0.0625
    }

    public init() {
        let session = AVAudioSession.sharedInstance()
        self.volume = Double(session.outputVolume)
        self.inferredComparisonVolume = session.outputVolume
        self.volumeView = MPVolumeView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        self.volumeView.showsVolumeSlider = true
        self.volumeView.isUserInteractionEnabled = false
        self.volumeView.alpha = 0.0001

        observation = session.observe(\.outputVolume, options: [.old, .new]) {
            [weak self] _, change in
            guard let self, let newValue = change.newValue else { return }
            let oldValue = change.oldValue ?? newValue
            Task { @MainActor in
                guard !self.isUserDragging else { return }
                self.volume = Double(newValue)
                self.onSystemVolumeChanged?(oldValue, newValue)
            }
        }

        registerSystemVolumeNotifications()
    }

    /// Lazily finds the UISlider inside the on-screen MPVolumeView and sets volume.
    public func applyVolumeToSystem() {
        guard let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider
        else { return }
        slider.setValue(Float(volume), animated: false)
    }

    public func activate() {
        guard !isActivated else { return }
        isActivated = true
        attachVolumeViewIfNeeded()
    }

    public func deactivate() {
        guard isActivated else { return }
        isActivated = false
        volumeView.removeFromSuperview()
    }

    public func registerWindow(_ window: UIWindow) {
        self.window = window
        attachVolumeViewIfNeeded()
    }

    private func attachVolumeViewIfNeeded() {
        guard isActivated, let window else { return }
        if volumeView.superview !== window {
            volumeView.removeFromSuperview()
            window.addSubview(volumeView)
        }
    }

    private func registerSystemVolumeNotifications() {
        let names: [Notification.Name] = [
            Notification.Name(rawValue: "SystemVolumeDidChange"),
            Notification.Name(rawValue: "AVSystemController_SystemVolumeDidChangeNotification"),
        ]

        for name in names {
            let token = NotificationCenter.default.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let self else { return }
                let userInfo = notification.userInfo
                let sequence = Self.extractSequenceNumber(from: userInfo)
                let reportedVolume = Self.extractVolume(from: userInfo)

                Task { @MainActor in
                    self.handleSystemVolumeNotification(
                        reportedVolume: reportedVolume,
                        sequenceNumber: sequence
                    )
                }
            }
            systemVolumeObserverTokens.append(token)
        }
    }

    private func handleSystemVolumeNotification(reportedVolume: Float?, sequenceNumber: Int?) {
        guard !isUserDragging else { return }

        if let sequence = sequenceNumber {
            if lastVolumeNotificationSequenceNumber == sequence {
                return
            }
            lastVolumeNotificationSequenceNumber = sequence
        }

        guard let reportedVolume else { return }
        self.volume = Double(reportedVolume)

        if let direction = inferButtonDirection(for: reportedVolume) {
            onSystemVolumeButtonEvent?(direction, reportedVolume)
        }
    }

    private func inferButtonDirection(for reportedVolume: Float) -> VolumeButtonEventDirection?
    {
        let previousComparisonVolume = inferredComparisonVolume
        let effectiveComparisonVolume: Float

        if reportedVolume <= ButtonInference.edgeEpsilon {
            effectiveComparisonVolume = ButtonInference.stepSize
        } else if reportedVolume >= 1 - ButtonInference.edgeEpsilon {
            effectiveComparisonVolume = 1 - ButtonInference.stepSize
        } else {
            effectiveComparisonVolume = previousComparisonVolume
        }

        let direction: VolumeButtonEventDirection?
        if reportedVolume > effectiveComparisonVolume + ButtonInference.edgeEpsilon {
            direction = .up
        } else if reportedVolume < effectiveComparisonVolume - ButtonInference.edgeEpsilon {
            direction = .down
        } else if reportedVolume >= 1 - ButtonInference.edgeEpsilon,
            previousComparisonVolume >= 1 - ButtonInference.edgeEpsilon
        {
            direction = .up
        } else if reportedVolume <= ButtonInference.edgeEpsilon,
            previousComparisonVolume <= ButtonInference.edgeEpsilon
        {
            direction = .down
        } else {
            direction = nil
        }

        inferredComparisonVolume = reportedVolume
        return direction
    }

    nonisolated private static func extractSequenceNumber(from userInfo: [AnyHashable: Any]?)
        -> Int?
    {
        guard let userInfo else { return nil }

        if let sequence = userInfo["SequenceNumber"] as? Int {
            return sequence
        }

        if let number = userInfo["SequenceNumber"] as? NSNumber {
            return number.intValue
        }

        return nil
    }

    nonisolated private static func extractVolume(from userInfo: [AnyHashable: Any]?) -> Float?
    {
        guard let userInfo else { return nil }

        if let value = userInfo["Volume"] as? Float {
            return value
        }

        if let value = userInfo["Volume"] as? Double {
            return Float(value)
        }

        if let value = userInfo["Volume"] as? NSNumber {
            return value.floatValue
        }

        if let value = userInfo["AVSystemController_AudioVolumeNotificationParameter"] as? Float
        {
            return value
        }

        if let value = userInfo["AVSystemController_AudioVolumeNotificationParameter"]
            as? Double
        {
            return Float(value)
        }

        if let value = userInfo["AVSystemController_AudioVolumeNotificationParameter"]
            as? NSNumber
        {
            return value.floatValue
        }

        return nil
    }

    @MainActor deinit {
        observation?.invalidate()
        for token in systemVolumeObserverTokens {
            NotificationCenter.default.removeObserver(token)
        }
        systemVolumeObserverTokens.removeAll()
        volumeView.removeFromSuperview()
    }
}
#endif
