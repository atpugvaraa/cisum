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

// MARK: - System Volume Controller
/// Single source of truth for system volume.
/// Observes hardware changes via KVO and sets volume through MPVolumeView's UISlider.
@Observable @MainActor
final class SystemVolumeController {
    /// The current volume (0.0 – 1.0).
    var volume: Double = 0.0
    
    /// Whether the user is currently dragging the custom slider.
    var isUserDragging: Bool = false
    
    /// Reference to the MPVolumeView in the hierarchy (used to find UISlider lazily).
    weak var volumeView: MPVolumeView?
    
    private var observation: NSKeyValueObservation?
    
    init() {
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(true)
        self.volume = Double(session.outputVolume)
        
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
        guard let slider = volumeView?.subviews.first(where: { $0 is UISlider }) as? UISlider else { return }
        slider.setValue(Float(volume), animated: false)
    }
    
    @MainActor deinit {
        observation?.invalidate()
    }
}

// MARK: - Hidden MPVolumeView
/// Must be in the view hierarchy for programmatic volume control to work.
/// Uses a Coordinator to hand the live MPVolumeView reference to the controller.
struct SystemVolumeView: UIViewRepresentable {
    let controller: SystemVolumeController
    
    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView(frame: .zero)
        view.alpha = 0.001
        view.showsVolumeSlider = true
        // Store the live view reference — UISlider subview exists once it's in a window
        controller.volumeView = view
        return view
    }
    
    func updateUIView(_ uiView: MPVolumeView, context: Context) {
        // Re-grab reference in case SwiftUI recreated the view
        controller.volumeView = uiView
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
            // Hidden MPVolumeView must be in the view hierarchy
            SystemVolumeView(controller: volumeController)
                .frame(width: 0, height: 0)
            
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
