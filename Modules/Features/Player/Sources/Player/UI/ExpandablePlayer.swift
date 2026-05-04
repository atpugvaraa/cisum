//
//  ExpandablePlayer.swift
//  cisum
//
//  Created by Aarav Gupta (github.com/atpugvaraa) on 10/05/25.
//

import DesignSystem
import SwiftUI
import Services
import Utilities

public struct ExpandablePlayer: View {
    @Environment(\.tabBarVisibility) private var tabBarVisibility
    @Environment(\.isSearchExpanded) private var isSearchExpanded

    @Binding public var show: Bool
    @Binding public var isPlayerExpanded: Bool

    public var collapsedFrame: CGRect

    public init(show: Binding<Bool>, isPlayerExpanded: Binding<Bool>, collapsedFrame: CGRect) {
        self._show = show
        self._isPlayerExpanded = isPlayerExpanded
        self.collapsedFrame = collapsedFrame
    }

    var isSearchFieldExpanded: Bool {
        return isSearchExpanded.wrappedValue
    }

    var isTabbarVisible: Bool {
        if tabBarVisibility == .visible {
            return true
        } else {
            return false
        }
    }

    @Namespace private var namespace

    @State private var offsetY: CGFloat = 0.0
    @State private var needRestoreProgressOnActive: Bool = false
    @State private var mainWindow: UIWindow?
    @State private var windowProgress: CGFloat = 0.0
    @State private var progressTrackState: CGFloat = 0.0
    @State private var expandProgress: CGFloat = 0.0

    var currentOrientation: UIDeviceOrientation = .portrait

    public var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                GeometryReader { proxy in
                    let size = proxy.size
                    let safeArea = proxy.safeAreaInsets

                    playerContent(size: size)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .padding(
                            .bottom,
                            isPlayerExpanded
                                ? 0
                                : (isSearchFieldExpanded
                                    ? (isTabbarVisible ? safeArea.bottom + 18 : -12)
                                    : safeArea.bottom + 25)
                        )
                        .padding(
                            .horizontal,
                            isPlayerExpanded
                                ? 0
                                : (isTabbarVisible
                                    ? (isSearchFieldExpanded ? 30 : 20)
                                    : (isSearchFieldExpanded ? 20 : 10))
                        )
                        .gesture(
                            PanGesture { newValue in
                                handleGestureChange(value: newValue, viewSize: size)
                            } onEnd: { newValue in
                                handleGestureEnd(value: newValue, viewSize: size)
                            }
                        )
                }
                .opacity(isFullyCollapsed ? 0 : 1)
                .onChange(of: isPlayerExpanded) { _, expanded in
                    DesignSystem.PlayerExpansionState.shared.isExpanded = expanded
                    if expanded {
                        stacked(progress: 1, withAnimation: true)
                    } else {
                        resetStackedWithAnimation()
                    }
                }
                .onPreferenceChange(NowPlayingExpandProgressPreferenceKey.self) { value in
                    if expandProgress != value {
                        expandProgress = value
                    }
                }
            } else {
                GeometryReader { proxy in
                    let size = proxy.size
                    let safeArea = proxy.safeAreaInsets

                    playerContent(size: size)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .padding(
                            .bottom,
                            isPlayerExpanded
                                ? 0 : safeArea.bottom + (isSearchExpanded.wrappedValue ? 77 : 88)
                        )
                        .padding(.horizontal, isPlayerExpanded ? 0 : 20)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    guard isPlayerExpanded else { return }
                                    let translation = max(value.translation.height, 0)
                                    offsetY = translation
                                    windowProgress = max(min(translation / size.height, 1), 0) * 0.1

                                    resizeWindow(0.1 - windowProgress)
                                }
                                .onEnded { value in
                                    guard isPlayerExpanded else { return }
                                    let translation = max(value.translation.height, 0)
                                    let velocity = value.velocity.height / 5

                                    withAnimation(.smooth(duration: 0.3, extraBounce: 0)) {
                                        if (translation + velocity) > (size.height * 0.3) {
                                            /// Closing View
                                            isPlayerExpanded = false
                                            /// Resetting Window to identity with Animation
                                            resetWindowWithAnimation()
                                        } else {
                                            /// Reset window to 0.1 with animation
                                            UIView.animate(withDuration: 0.3) {
                                                resizeWindow(0.1)
                                            }
                                        }

                                        offsetY = 0
                                    }
                                }, including: isPlayerExpanded ? .all : .subviews)
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    if isPlayerExpanded {
                        resetWindowToIdentity()
                    }
                }
                .onChange(of: isPlayerExpanded) { _, expanded in
                    DesignSystem.PlayerExpansionState.shared.isExpanded = expanded
                    if expanded {
                        applyExpandedWindowTransform()
                    } else {
                        resetWindowWithAnimation()
                    }
                }
            }
        }
        .onAppear {
            DesignSystem.PlayerExpansionState.shared.isExpanded = isPlayerExpanded
            if let window = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.keyWindow, mainWindow == nil {
                mainWindow = window
            }
        }
    }
}

extension ExpandablePlayer {
    fileprivate func applyExpandedWindowTransform() {
        UIView.animate(withDuration: Animation.playerExpandAnimationDuration) {
            resizeWindow(0.1)
        }
    }

    fileprivate func resetWindowToIdentity() {
        mainWindow?.subviews.first?.transform = .identity
    }

    fileprivate func resizeWindow(_ progress: CGFloat) {
        if let mainWindow = mainWindow?.subviews.first {
            let offsetY = (mainWindow.frame.height * progress) / 2

            /// Corner Radius
            mainWindow.layer.cornerRadius = (progress / 0.1) * 30
            mainWindow.layer.masksToBounds = true
            mainWindow.transform = .identity.scaledBy(x: 1 - progress, y: 1 - progress).translatedBy(x: 0, y: offsetY)
        }
    }

    fileprivate func resetWindowWithAnimation() {
        if let mainWindow = mainWindow?.subviews.first {
            UIView.animate(withDuration: 0.3) {
                mainWindow.layer.cornerRadius = 0
                mainWindow.transform = .identity
            }
        }
    }
}

extension ExpandablePlayer {
    fileprivate var isFullyExpanded: Bool {
        expandProgress >= 1
    }

    fileprivate var isFullyCollapsed: Bool {
        expandProgress.isZero
    }

    fileprivate func playerContent(size: CGSize) -> some View {
        ZStack(alignment: .top) {
            PlayerBackground(
                isPlayerExpanded: isPlayerExpanded,
                isFullExpanded: isFullyExpanded
            )

            DynamicPlayerIsland(
                isPlayerExpanded: $isPlayerExpanded,
                namespace: namespace
            )
            .opacity(isPlayerExpanded ? 0 : 1)

            NowPlayingView(
                isPlayerExpanded: isPlayerExpanded,
                size: size,
                namespace: namespace
            )
            .opacity(isPlayerExpanded ? 1 : 0)

            ProgressTracker(progress: progressTrackState)
        }
        .frame(height: isPlayerExpanded ? nil : Utilities.AppConstants.dynamicPlayerIslandHeight, alignment: .top)
        .offset(y: offsetY)
        .ignoresSafeArea()
    }

    fileprivate func handleGestureChange(value: PanGesture.Value, viewSize: CGSize) {
        guard isPlayerExpanded else { return }
        let translation = max(value.translation.height, 0)
        offsetY = translation
        windowProgress = max(min(translation / viewSize.height, 1), 0)
        stacked(progress: 1 - windowProgress, withAnimation: false)
    }

    fileprivate func handleGestureEnd(value: PanGesture.Value, viewSize: CGSize) {
        guard isPlayerExpanded else { return }
        let translation = max(value.translation.height, 0)
        let velocity = value.velocity.height / 5
        withAnimation(.playerExpandAnimation) {
            if (translation + velocity) > (viewSize.height * 0.3) {
                isPlayerExpanded = false
                resetStackedWithAnimation()
            } else {
                stacked(progress: 1, withAnimation: true)
            }
            offsetY = 0
        }
    }

    fileprivate func stacked(progress: CGFloat, withAnimation: Bool) {
        if withAnimation {
            SwiftUI.withAnimation(.playerExpandAnimation) {
                progressTrackState = progress
            }
        } else {
            progressTrackState = progress
        }
    }

    fileprivate func resetStackedWithAnimation() {
        withAnimation(.playerExpandAnimation) {
            progressTrackState = 0
        }
    }
}

private struct ProgressTracker: View, @preconcurrency Animatable {
    var progress: CGFloat = 0

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .preference(key: NowPlayingExpandProgressPreferenceKey.self, value: progress)
    }
}
