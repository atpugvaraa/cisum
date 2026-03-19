//
//  ExpandablePlayer.swift
//  cisum
//
//  Created by Aarav Gupta (github.com/atpugvaraa) on 10/05/25.
//

import SwiftUI
import Kingfisher

#if os(iOS)
struct ExpandablePlayer: View {
    @Environment(PlayerViewModel.self) private var playerViewModel
    
    @Binding var show: Bool
    @Namespace private var namespace
    
    @State private var properties = PlayerProperties.shared
    
    #if DEBUG
    @ObserveInjection var forceRedraw
    #endif

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let safeArea = proxy.safeAreaInsets
            
            ZStack(alignment: .top) {
                background
                
                DynamicPlayerIsland(namespace: namespace)
                    .opacity(properties.isPlayerExpanded ? 0 : 1)
                
                NowPlayingView(namespace: namespace)
                    .opacity(properties.isPlayerExpanded ? 1 : 0)
            }
            .frame(height: properties.isPlayerExpanded ? nil : 45, alignment: .top)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, properties.isPlayerExpanded ? 0 : safeArea.bottom + 88)
            .padding(.horizontal, properties.isPlayerExpanded ? 0 : 20)
            .offset(y: properties.offsetY)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard properties.isPlayerExpanded else { return }
                        let translation = max(value.translation.height, 0)
                        properties.offsetY = translation
                        properties.windowProgress = max(min(translation / size.height, 1), 0) * 0.1
                        
                        properties.resizeWindow(0.1 - properties.windowProgress)
                    }
                    .onEnded { value in
                        guard properties.isPlayerExpanded else { return }
                        let translation = max(value.translation.height, 0)
                        let velocity = value.velocity.height / 5
                        
                        withAnimation(.smooth(duration: 0.3, extraBounce: 0)) {
                            if (translation + velocity) > (size.height * 0.3) {
                                /// Closing View
                                properties.isPlayerExpanded = false
                                /// Resetting Window to identity with Animation
                                properties.resetWindowWithAnimation()
                            } else {
                                /// Reset window to 0.1 with animation
                                UIView.animate(withDuration: 0.3) {
                                    properties.resizeWindow(0.1)
                                }
                            }
                            
                            properties.offsetY = 0
                        }
                    }
            , including: .all)
            .ignoresSafeArea()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            if properties.isPlayerExpanded {
                properties.resetWindowToIdentity()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            properties.handleOrientationChange(UIDevice.current.orientation)
        }
        .enableInjection()
    }
    
    var playerBackgroundClipShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: properties.isPlayerExpanded ? deviceCornerRadius : 50)
    }
    
    var background: some View {
        ZStack {
            Rectangle()
                .fill(.bar)
            
            Rectangle()
                .fill(.ultraThickMaterial)
                .overlay {
                    nowPlayingBackground
                }
                .opacity(properties.isPlayerExpanded ? 1 : 0)
        }
        .clipShape(playerBackgroundClipShape)
        .frame(height: properties.isPlayerExpanded ? nil : 44)
    }
    
    var nowPlayingBackground: some View {
        ZStack {
            dominantColor
            
            vinylEffect
            
            overlayEffects
        }
        .compositingGroup()
    }
    
    var dominantColor: some View {
        Color.dynamicAccent
            .scaleEffect(1.1)
            .blur(radius: 10)
    }
    
    var vinylEffect: some View {
        Vinyl {
            KFImage(playerViewModel.currentImageURL)
                .resizable()
                .scaledToFill()
        }
    }
    
    var overlayEffects: some View {
        ZStack {
            Color.white.opacity(0.1)
                .scaleEffect(1.8)
                .blur(radius: 100)
            
            Color.black.opacity(0.35)
        }
        .compositingGroup()
    }
}
#endif
