//
//  UniversalOverlay.swift
//  cisum
//
//  Created by Aarav Gupta (github.com/atpugvaraa) on 03/05/25.
//

import SwiftUI

public struct PlayerOverlayState: Sendable, Equatable {
    public let isExpanded: Bool
    public let progress: Double

    public init(isExpanded: Bool = false, progress: Double = 0.0) {
        self.isExpanded = isExpanded
        self.progress = progress
    }
}

public struct PlayerOverlayStateKey: EnvironmentKey {
    public static let defaultValue = PlayerOverlayState()
}

public extension EnvironmentValues {
    var playerOverlayState: PlayerOverlayState {
        get { self[PlayerOverlayStateKey.self] }
        set { self[PlayerOverlayStateKey.self] = newValue }
    }
}

#if os(iOS)
    public extension View {
        @ViewBuilder
        func universalOverlay<Content: View>(
            animation: Animation = .easeInOut,
            show: Binding<Bool>,
            @ViewBuilder content: @escaping () -> Content
        ) -> some View {
            self
                .modifier(
                    UniversalOverlayModifier(animation: animation, show: show, viewContent: content)
                )
        }
    }

    /// Root View Wrapper
    public struct RootView<Content: View>: View {
        private let content: Content
        private let playerOverlayState: PlayerOverlayState
        private let overlayWrapper: (AnyView) -> AnyView
        @State private var properties = UniversalOverlayProperties()

        public init(
            playerOverlayState: PlayerOverlayState,
            @ViewBuilder content: @escaping () -> Content,
            overlayWrapper: @escaping (AnyView) -> AnyView = { $0 }
        ) {
            self.content = content()
            self.playerOverlayState = playerOverlayState
            self.overlayWrapper = overlayWrapper
        }

        public var body: some View {
            content
                .environment(properties)
                .onAppear {
                    setupOverlayWindowIfNeeded()
                }
                .onDisappear {
                    teardownOverlayWindow()
                }

        }

        private func setupOverlayWindowIfNeeded() {
            guard properties.window == nil else { return }
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
            else { return }

            let window = PassThroughWindow(windowScene: windowScene)
            window.frame = windowScene.coordinateSpace.bounds
            window.backgroundColor = .clear
            window.windowLevel = .statusBar + 1
            window.isHidden = false
            window.isUserInteractionEnabled = true

            // Keep a dedicated SwiftUI tree for overlay rendering.
            let rootViewController = UIHostingController(
                rootView: overlayWrapper(
                    AnyView(
                        UniversalOverlayViews()
                            .environment(properties)
                    )
                )
                .environment(\.playerOverlayState, playerOverlayState)
            )
            rootViewController.view.backgroundColor = .clear
            rootViewController.view.frame = window.bounds
            rootViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            window.rootViewController = rootViewController

            properties.window = window
        }

        private func teardownOverlayWindow() {
            properties.views.removeAll(keepingCapacity: false)
            properties.window?.isHidden = true
            properties.window = nil
        }
    }

    /// Shared Universal Overlay Properties
    @Observable
    class UniversalOverlayProperties {
        var window: UIWindow?
        var views: [OverlayView] = []

        struct OverlayView: Identifiable {
            var id: String = UUID().uuidString
            var view: AnyView
        }
    }

    private struct UniversalOverlayModifier<ViewContent: View>: ViewModifier {
        var animation: Animation
        @Binding var show: Bool
        @ViewBuilder var viewContent: ViewContent
        /// Local View Properties
        @Environment(UniversalOverlayProperties.self) private var properties
        @State private var viewID: String = UUID().uuidString

        func body(content: Content) -> some View {
            content
                .onAppear {
                    syncOverlayVisibility()
                }
                .onDisappear {
                    removeView()
                }
                .onChange(of: show) { oldValue, newValue in
                    syncOverlayVisibility()
                }
                .onChange(of: properties.window != nil) { _, isReady in
                    if isReady {
                        syncOverlayVisibility()
                    }
                }

        }

        private func syncOverlayVisibility() {
            if show {
                addViewIfNeeded()
            } else {
                removeView()
            }
        }

        private func addViewIfNeeded() {
            guard properties.window != nil else { return }
            guard !properties.views.contains(where: { $0.id == viewID }) else { return }

            withAnimation(animation) {
                properties.views.append(
                    .init(
                        id: viewID,
                        view: .init(
                            viewContent
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .ignoresSafeArea()
                        )
                    )
                )
            }
        }

        private func removeView() {
            guard properties.views.contains(where: { $0.id == viewID }) else { return }

            withAnimation(animation) {
                properties.views.removeAll(where: { $0.id == viewID })
            }
        }
    }

    private struct UniversalOverlayViews: View {
        @Environment(UniversalOverlayProperties.self) private var properties

        var body: some View {
            ZStack {
                ForEach(properties.views) {
                    $0.view
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()

        }
    }

    @Observable
    public final class PlayerExpansionState {
        @MainActor public static let shared = PlayerExpansionState()
        public var isExpanded: Bool = false
    }

    private class PassThroughWindow: UIWindow {
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            // If the player is expanded, capture all touches to enable gestures.
            if PlayerExpansionState.shared.isExpanded {
                return super.hitTest(point, with: event)
            }

            guard let hitView = super.hitTest(point, with: event),
                let rootView = rootViewController?.view
            else { return nil }

            if #available(iOS 18, *) {
                for subview in rootView.subviews.reversed() {
                    /// Finding if any of rootview's child is recieving hit test
                    let pointInSubView = subview.convert(point, from: rootView)
                    if subview.hitTest(pointInSubView, with: event) != nil {
                        return hitView
                    }
                }

                return nil
            } else {
                return hitView == rootView ? nil : hitView
            }
        }
    }
#else
    public extension View {
        @ViewBuilder
        func universalOverlay<Content: View>(
            animation: Animation = .easeInOut,
            show: Binding<Bool>,
            @ViewBuilder content: @escaping () -> Content
        ) -> some View {
            self
        }
    }

    public struct RootView<Content: View>: View {
        var content: Content

        public init(
            playerOverlayState: PlayerOverlayState,
            @ViewBuilder content: @escaping () -> Content,
            overlayWrapper: @escaping (AnyView) -> AnyView = { $0 }
        ) {
            self.content = content()
        }

        public var body: some View {
            content
        }
    }
#endif
