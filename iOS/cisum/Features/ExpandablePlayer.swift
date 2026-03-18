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
                // Background
                background
                
                DynamicPlayerIsland(namespace: namespace)
                    .opacity(properties.isPlayerExpanded ? 0 : 1)
                
                NowPlayingView(namespace: namespace)
                    .opacity(properties.isPlayerExpanded ? 1 : 0)
            }
            .frame(height: properties.isPlayerExpanded ? nil : 45, alignment: .top)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, properties.isPlayerExpanded ? 0 : safeArea.bottom + 55)
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
            // .simultaneousGesture(
            //     TapGesture(count: 2)
            //         .onEnded {
            //             if expandPlayer {
            //                 withAnimation(.smooth(duration: 0.3, extraBounce: 0)) {
            //                     expandPlayer = false
            //                     resetWindowWithAnimation()
            //                 }
            //             }
            //         }
            // )
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
    
    var playerBackgroundClipShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: properties.isPlayerExpanded ? 150 : 50, bottomLeadingRadius: properties.isPlayerExpanded ? deviceCornerRadius : 50, bottomTrailingRadius: properties.isPlayerExpanded ? deviceCornerRadius : 50, topTrailingRadius: properties.isPlayerExpanded ? 150 : 50)
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
            
            backgroundEffects
            
            overlayEffects
        }
    }
    
    var dominantColor: some View {
        Color.dynamicAccent
            .scaleEffect(1.1)
            .blur(radius: 10)
    }
    
    var backgroundEffects: some View {
        KFImage(playerViewModel.currentImageURL)
            .resizable()
            .scaledToFill()
            .blur(radius: 100, opaque: true)
            .scaleEffect(1.25)
            .opacity(0.6)
            .saturation(properties.saturation)
            .rotationEffect(.degrees(properties.isRotating))
            .onAppear {
                withAnimation(.linear(duration: 36)
                    .repeatForever(autoreverses: false)) {
                        properties.isRotating = properties.isRotating + 360
                    }
            }
            .onReceive(properties.timer) { _ in
                withAnimation(.linear(duration: 6)) {
                    properties.saturation = Double.random(in: 0.7...2)
                }
            }
    }
    
    var overlayEffects: some View {
        ZStack {
            Color.white.opacity(0.1)
                .scaleEffect(1.8)
                .blur(radius: 100)
            
            Color.black.opacity(0.35)
        }
    }
}
#endif
