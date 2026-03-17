//
//  NowPlayingView.swift
//  cisum
//
//  Created by Aarav Gupta on 05/12/25.
//

import AVKit
import LNPopupUI
import Kingfisher
import YouTubeSDK
import SwiftUI

struct NowPlayingView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(PlayerViewModel.self) var playerViewModel
    
    enum PlayerMode { case video, audio }
    @State private var playerMode: PlayerMode = .video
    
    var namespace: Namespace.ID
    @State private var properties = PlayerProperties.shared
    
    #if DEBUG
    @ObserveInjection var forceRedraw
    #endif
    
    var body: some View {
        ZStack {
            if #available(iOS 26.0, *) {
                Rectangle()
                    .fill(.ultraThickMaterial)
                    .overlay {
                        nowPlayingBackground
                    }
                    .ignoresSafeArea()
                
                playerView
            } else {
                playerView
                    .safeAreaPadding(.top)
                    .safeAreaPadding(.top)
                    .safeAreaPadding(.top)
                    .safeAreaPadding(.top)
                    .safeAreaPadding(.bottom)
                    .ignoresSafeArea()
            }
        }
        .popupItem {
            let id: String = playerViewModel.currentVideoId ?? UUID().uuidString
            let title: String = playerViewModel.currentTitle
            let subtitle: String = playerViewModel.currentArtist
            let image: Image = Image(systemName: "music.note")
            let progress: Float = Float(playerViewModel.currentTime / max(playerViewModel.duration, 1))
            
            return PopupItem(
                id: id,
                title: title,
                subtitle: subtitle,
                image: image,
                progress: progress
            ) {
                ToolbarItemGroup(placement: .popupBar) {
                    Button {
                        playerViewModel.togglePlayPause()
                    } label: {
                        Image(systemName: playerViewModel.isPlaying ? "pause.fill" : "play.fill")
                    }
                }
            }
        }
        .onChange(of: playerMode) { _, _ in
            playerViewModel.reloadCurrentVideo()
        }
        .animation(.smooth(duration: 0.35), value: properties.isPlayerExpanded)
        .enableInjection()
    }
    
    var playerView: some View {
        VStack(spacing: 12) {
            header
            
            artwork
            
            songInfo
            
            playerControls
        }
        .padding(.top, 10)
        .padding(.vertical, 20)
        .padding(.horizontal, 15)
    }
    
    var nowPlayingBackground: some View {
        ZStack {
            dominantColor
            
            backgroundEffects
            
            overlayEffects
        }
        .compositingGroup()
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
        .compositingGroup()
    }
    
    @ViewBuilder
    var header: some View {
        VStack {
            Capsule()
                .fill(.white)
                .blendMode(.overlay)
                .offset(y: -10)
                .onTapGesture {
                    withAnimation(.smooth(duration: 0.3, extraBounce: 0)) {
                        /// Closing View
                        properties.isPlayerExpanded = false
                        /// Resetting Window to identity with Animation
                        properties.resetWindowWithAnimation()
                        
                        properties.offsetY = 0
                    }
                }
        }
        .frame(width: 40, height: 5)
    }
    
    @ViewBuilder
    var artwork: some View {
        GeometryReader { geometry in
            VStack {
                if properties.isPlayerExpanded {
                    ZStack {
                        //                        Image(.notPlaying)
                        //                            .resizable()
                        //                            .aspectRatio(1, contentMode: .fit)
                        //                            .clipShape(.rect(cornerRadius: 12))
                        //                            .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 4)
                        //                            .transition(.offset(y: 1))
                        
                        VideoPlayer(player: playerViewModel.player)
                            .matchedGeometryEffect(id: "Artwork", in: namespace, properties: .frame, anchor: .center)
                        //                            .onTapGesture(count: 2) {
                        //                                withAnimation {
                        //                                    playerMode = (playerMode == .video) ? .audio : .video
                        //                                }
                        //                            }
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.width)
            .clipShape(.rect(cornerRadius: 12))
            .shadow(radius: 20)
        }
        .padding(.horizontal, 15)
    }
    
    @ViewBuilder
    var songInfo: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(playerViewModel.currentTitle)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    
                    if playerViewModel.isExplicit {
                        Text("E")
                            .font(.caption2.bold())
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(4)
                            .background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
                    }
                }
                
                Text(playerViewModel.currentArtist)
                    .font(.headline)
                    .foregroundColor(.white)
                    .blendMode(.overlay)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 12) {
                Button {
                    
                } label: {
                    Image(systemName: "star")
                }
                
                Button {
                    
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
            .foregroundStyle(.white)
            .font(.title2)
            .frame(alignment: .trailing)
        }
        .frame(height: 80)
        .padding(.top, 80)
        .padding(.horizontal, 15)
    }
    
    @ViewBuilder
    var playerControls: some View {
        GeometryReader {
            let size = $0.size
            let safeArea = $0.safeAreaInsets
            
            VStack {
                VStack {
                    cisumMusicProgressScrubber(currentTime: .constant(60), inRange: 0...240) { isEditing in
                        
                    }
                }
                .frame(height: 30)
                
                Spacer(minLength: 0)
                
                // Buttons
                HStack(spacing: size.width * 0.18) {
                    cisumBackwardButton()
                    
                    cisumPlayButton()
                    
                    cisumForwardButton()
                }
                .foregroundColor(.white)
                
                Spacer(minLength: 0)
                
                VStack {
                    cisumVolumeSlider(volume: .constant(60)) { isEditing in
                        
                    }
                }
                .frame(height: 30)
                
                Spacer(minLength: 0)
                
                // Bottom Buttons
                footer(size: size, safeArea: safeArea)
            }
            .padding(.horizontal, 15)
        }
    }
    
    @ViewBuilder
    func footer(size: CGSize, safeArea: EdgeInsets) -> some View {
        HStack(alignment: .top, spacing: size.width * 0.18) {
            Button {
                
            } label: {
                Image(systemName: "quote.bubble")
                    .font(.title2)
            }
            
//                    AirPlayButton()
//                        .frame(width: 48, height: 48)
//                        .padding(.top, -13)
            
//                    Button {
//                        player.toggleStreamType()
//                    } label: {
//                        if player.streamType == .song {
//                            Image(systemName: "airplayvideo")
//                                .font(.title2)
//                        } else {
//                            Image(systemName: "waveform")
//                                .font(.title2)
//                        }
//                    }
//                    .disabled(player.streamType == .song && !player.isVideoAvailable)
//                    .opacity((player.streamType == .song && !player.isVideoAvailable) ? 0.5 : 1.0)
            
            Button {
                withAnimation {
                    
                }
                // Optional: Show a toast or feedback that queue was cleared
            } label: {
                Image(systemName: "list.bullet")
                    .font(.title2)
            }
        }
        .foregroundColor(.white)
        .blendMode(.overlay)
    }
    
    func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite else { return "0:00" }
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}
