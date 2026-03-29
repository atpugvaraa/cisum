//
//  cisumVolumeSlider.swift
//  cisum
//
//  Created by Aarav Gupta (github.com/atpugvaraa) on 04/05/25.
//

#if os(iOS)

import SwiftUI
import MediaPlayer
import AVFoundation
import UIKit

extension View {
    public func systemVolumeController(
        _ controller: SystemVolumeController,
        showsSystemVolumeHUD: Bool = false
    ) -> some View {
        modifier(SystemVolumeModifier(controller: controller, showsSystemVolumeHUD: showsSystemVolumeHUD))
    }
}

// MARK: - System Volume Controller
/// Single source of truth for system volume.
/// Observes hardware changes via KVO and sets volume through MPVolumeView's UISlider.
@Observable @MainActor
public final class SystemVolumeController {
    enum VolumeButtonEventDirection {
        case up
        case down
    }

    @MainActor static let shared = SystemVolumeController()

    /// The current volume (0.0 – 1.0).
    var volume: Double = 0.0

    /// Observes normalized volume transitions from hardware buttons and programmatic updates.
    var onSystemVolumeChanged: ((Float, Float) -> Void)?

    /// Emits inferred hardware button direction events, including boundary presses.
    var onSystemVolumeButtonEvent: ((VolumeButtonEventDirection, Float) -> Void)?
    
    /// Whether the user is currently dragging the custom slider.
    var isUserDragging: Bool = false

    /// Controls whether the backing MPVolumeView is visually hidden.
    var showsSystemVolumeHUD: Bool = false {
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

    init() {
        let session = AVAudioSession.sharedInstance()
        self.volume = Double(session.outputVolume)
        self.inferredComparisonVolume = session.outputVolume
        self.volumeView = MPVolumeView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        self.volumeView.showsVolumeSlider = true
        self.volumeView.showsRouteButton = false
        self.volumeView.isUserInteractionEnabled = false
        self.volumeView.alpha = 0.0001
        
        observation = session.observe(\.outputVolume, options: [.old, .new]) { [weak self] _, change in
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
    func applyVolumeToSystem() {
        guard let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider else { return }
        slider.setValue(Float(volume), animated: false)
    }

    func activate() {
        guard !isActivated else { return }
        isActivated = true
        attachVolumeViewIfNeeded()
    }

    func deactivate() {
        guard isActivated else { return }
        isActivated = false
        volumeView.removeFromSuperview()
    }

    func registerWindow(_ window: UIWindow) {
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
            Notification.Name(rawValue: "AVSystemController_SystemVolumeDidChangeNotification")
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

    private func inferButtonDirection(for reportedVolume: Float) -> VolumeButtonEventDirection? {
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
                  previousComparisonVolume >= 1 - ButtonInference.edgeEpsilon {
            direction = .up
        } else if reportedVolume <= ButtonInference.edgeEpsilon,
                  previousComparisonVolume <= ButtonInference.edgeEpsilon {
            direction = .down
        } else {
            direction = nil
        }

        inferredComparisonVolume = reportedVolume
        return direction
    }

    nonisolated private static func extractSequenceNumber(from userInfo: [AnyHashable: Any]?) -> Int? {
        guard let userInfo else { return nil }

        if let sequence = userInfo["SequenceNumber"] as? Int {
            return sequence
        }

        if let number = userInfo["SequenceNumber"] as? NSNumber {
            return number.intValue
        }

        return nil
    }

    nonisolated private static func extractVolume(from userInfo: [AnyHashable: Any]?) -> Float? {
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

        if let value = userInfo["AVSystemController_AudioVolumeNotificationParameter"] as? Float {
            return value
        }

        if let value = userInfo["AVSystemController_AudioVolumeNotificationParameter"] as? Double {
            return Float(value)
        }

        if let value = userInfo["AVSystemController_AudioVolumeNotificationParameter"] as? NSNumber {
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

// MARK: - Hidden MPVolumeView
fileprivate struct SystemVolumeModifier: ViewModifier {
    let controller: SystemVolumeController
    let showsSystemVolumeHUD: Bool

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .topLeading) {
                IntrospectView { view in
                    guard let window = view.window else { return }
                    controller.registerWindow(window)
                }
                .frame(width: 1, height: 1)
                .opacity(0.001)
                .allowsHitTesting(false)
            }
            .onAppear {
                controller.showsSystemVolumeHUD = showsSystemVolumeHUD
                controller.activate()
            }
            .onDisappear {
                controller.deactivate()
            }
            .onChange(of: showsSystemVolumeHUD, initial: true) { value, _ in
                controller.showsSystemVolumeHUD = value
            }
    }
}

@MainActor
fileprivate struct IntrospectView: UIViewRepresentable {
    let handler: (UIView) -> Void

    func makeUIView(context: Context) -> UIView {
        ObservableView(didMoveToWindowHandler: handler)
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

fileprivate final class ObservableView: UIView {
    let didMoveToWindowHandler: (UIView) -> Void

    init(didMoveToWindowHandler: @escaping (UIView) -> Void) {
        self.didMoveToWindowHandler = didMoveToWindowHandler
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        didMoveToWindowHandler(self)
    }
}

// MARK: - cisumVolumeSlider
struct cisumVolumeSlider: View {
    /// Internal single source of truth — no external binding needed
    @State private var volumeController: SystemVolumeController = .shared
    
    @State private var minVolumeAnimationTrigger: Bool = false
    @State private var maxVolumeAnimationTrigger: Bool = false
    
    let range: ClosedRange<Double>
    let onEditingChanged: (Bool) -> Void
    
    init(
        volume: Binding<Double> = .constant(0),
        in range: ClosedRange<Double> = 0.0...1.0,
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.range = range
        self.onEditingChanged = onEditingChanged
    }

    #if DEBUG
    @ObserveInjection var forceRedraw
    #endif

    public var body: some View {
        ZStack {
            StretchySlider(
                value: $volumeController.volume,
                in: range,
                leadingLabel: {
                    Image(systemName: "speaker.fill")
                        .padding(.trailing, 20)
                        .symbolEffect(.bounce, value: minVolumeAnimationTrigger)
                },
                trailingLabel: {
                    Image(systemName: "speaker.wave.3.fill")
                        .padding(.leading, 20)
                        .symbolEffect(.bounce, value: maxVolumeAnimationTrigger)
                },
                onEditingChanged: { editing in
                    volumeController.isUserDragging = editing
                    if editing {
                        // Start dragging — apply immediately for responsiveness
                        volumeController.applyVolumeToSystem()
                    } else {
                        // Finished dragging — final apply
                        volumeController.applyVolumeToSystem()
                    }
                    onEditingChanged(editing)
                }
            )
            .sliderStyle(.volume)
            .font(.system(size: 14))
        }
        .onChange(of: volumeController.volume) {
            // Real-time system volume update while dragging
            if volumeController.isUserDragging {
                volumeController.applyVolumeToSystem()
            }
            
            if volumeController.volume <= range.lowerBound {
                minVolumeAnimationTrigger.toggle()
            }
            if volumeController.volume >= range.upperBound {
                maxVolumeAnimationTrigger.toggle()
            }
        }
        .frame(height: 50)
        .systemVolumeController(volumeController, showsSystemVolumeHUD: false)
        .enableInjection()
    }
}

extension cisumSliderConfig {
    static var volume: Self {
        Self(
            labelLocation: .side,
            maxStretch: 10,
            minimumTrackActiveColor: .white,
            minimumTrackInactiveColor: Color(.init(white: 0.784, alpha: 0.816)),
            maximumTrackColor: Color(.init(white: 0.784, alpha: 0.816)),
            blendMode: .overlay,
            syncLabelsStyle: true
        )
    }
}

#endif
