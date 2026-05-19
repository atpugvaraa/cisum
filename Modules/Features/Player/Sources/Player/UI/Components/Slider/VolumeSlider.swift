//
//  cisumVolumeSlider.swift
//  cisum
//
//  Created by Aarav Gupta (github.com/atpugvaraa) on 04/05/25.
//

#if os(iOS)

    import SwiftUI
    import Services
    import MediaPlayer
    import AVFoundation
    import UIKit
    import DesignSystem

    extension View {
        public func systemVolumeController(
            _ controller: SystemVolumeController,
            showsSystemVolumeHUD: Bool = false
        ) -> some View {
            modifier(
                SystemVolumeModifier(
                    controller: controller, showsSystemVolumeHUD: showsSystemVolumeHUD))
        }
    }


    // MARK: - Hidden MPVolumeView
    private struct SystemVolumeModifier: ViewModifier {
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
    private struct IntrospectView: UIViewRepresentable {
        let handler: (UIView) -> Void

        func makeUIView(context: Context) -> UIView {
            ObservableView(didMoveToWindowHandler: handler)
        }

        func updateUIView(_ uiView: UIView, context: Context) {}
    }

    private final class ObservableView: UIView {
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

    // MARK: - VolumeSlider
public struct VolumeSlider: View {
    /// Internal single source of truth — no external binding needed
    @State private var volumeController: SystemVolumeController = .shared
    
    @State private var minVolumeAnimationTrigger: Bool = false
    @State private var maxVolumeAnimationTrigger: Bool = false
    
    let range: ClosedRange<Double>
    let onEditingChanged: (Bool) -> Void
    
    public init(
        volume: Binding<Double> = .constant(0),
        in range: ClosedRange<Double> = 0.0...1.0,
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.range = range
        self.onEditingChanged = onEditingChanged
    }
    
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
        
    }
}
#elseif os(macOS)
    import SwiftUI
    import Services
    import DesignSystem

    public struct VolumeSlider: View {
        @State private var volumeController: SystemVolumeController = .shared
        
        @State private var minVolumeAnimationTrigger: Bool = false
        @State private var maxVolumeAnimationTrigger: Bool = false
        
        let range: ClosedRange<Double>
        let onEditingChanged: (Bool) -> Void
        
        public init(
            volume: Binding<Double> = .constant(0),
            in range: ClosedRange<Double> = 0.0...1.0,
            onEditingChanged: @escaping (Bool) -> Void = { _ in }
        ) {
            self.range = range
            self.onEditingChanged = onEditingChanged
        }
        
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
                        volumeController.applyVolumeToSystem()
                        onEditingChanged(editing)
                    }
                )
                .sliderStyle(.volume)
                .font(.system(size: 14))
            }
            .onChange(of: volumeController.volume) {
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
        }
    }
#endif

