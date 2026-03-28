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
    /// The current volume (0.0 – 1.0).
    var volume: Double = 0.0
    
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
    
    init() {
        let session = AVAudioSession.sharedInstance()
        self.volume = Double(session.outputVolume)
        self.volumeView = MPVolumeView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        self.volumeView.showsVolumeSlider = true
        self.volumeView.showsRouteButton = false
        self.volumeView.isUserInteractionEnabled = false
        self.volumeView.alpha = 0.0001
        
        observation = session.observe(\.outputVolume, options: [.new]) { [weak self] _, change in
            guard let self, let newValue = change.newValue else { return }
            Task { @MainActor in
                guard !self.isUserDragging else { return }
                withAnimation(.smooth(duration: 0.25)) {
                    self.volume = Double(newValue)
                }
            }
        }
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
    
    @MainActor deinit {
        observation?.invalidate()
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
    @State private var volumeController = SystemVolumeController()
    
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
