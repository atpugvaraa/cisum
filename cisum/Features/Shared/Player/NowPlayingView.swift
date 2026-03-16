//
//  NowPlayingView.swift
//  cisum
//
//  Created by Aarav Gupta on 05/12/25.
//

import SwiftUI
import AVKit
import YouTubeSDK

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
    
    var playerBackgroundClipShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: properties.isPlayerExpanded ? 150 : 50, bottomLeadingRadius: properties.isPlayerExpanded ? deviceCornerRadius : 50, bottomTrailingRadius: properties.isPlayerExpanded ? deviceCornerRadius : 50, topTrailingRadius: properties.isPlayerExpanded ? 150 : 50)
    }

    var body: some View {
        ZStack {
            if #available(iOS 26.0, *) {
                Rectangle()
                    .fill(.ultraThickMaterial)
                    .overlay {
                        nowPlayingBackground
                    }
                    .ignoresSafeArea()
                    .opacity(properties.isPlayerExpanded ? 1 : 0)
            } else {
                Rectangle()
                    .fill(.ultraThickMaterial)
                    .overlay {
                        nowPlayingBackground
                    }
                    .ignoresSafeArea()
                    .opacity(properties.isPlayerExpanded ? 1 : 0)
                    .clipShape(playerBackgroundClipShape)
            }
            
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
        .onChange(of: playerMode) { _, _ in
            playerViewModel.reloadCurrentVideo()
        }
        .animation(.smooth(duration: 0.35), value: properties.isPlayerExpanded)
        .enableInjection()
        
        //        ZStack {
        //            LinearGradient(colors: [.red.opacity(0.8), .black], startPoint: .top, endPoint: .bottom)
        //                .ignoresSafeArea()
        //
        //            VStack(spacing: 20) {
        //
        //                Spacer()
        //
        //
        //
        //                Picker("Mode", selection: $playerMode) {
        //                    Image(systemName: "video.fill").tag(PlayerMode.video)
        //                    Image(systemName: "music.note").tag(PlayerMode.audio)
        //                }
        //                    .pickerStyle(.segmented)
        //                    .frame(width: 150)
        //                    .padding(.top, 10)
        //
        //                Spacer()
        //
        //                VStack(alignment: .leading, spacing: 5) {
        //                    HStack {
        //                        Text(playerViewModel.currentTitle)
        //                            .font(.title2.bold())
        //                            .foregroundStyle(.white)
        //                            .lineLimit(1)
        //
        //                        if playerViewModel.isExplicit {
        //                            Text("E")
        //                                .font(.caption2.bold())
        //                                .foregroundStyle(.white.opacity(0.8))
        //                                .padding(4)
        //                                .background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
        //                        }
        //                    }
        //
        //                    Text(playerViewModel.currentArtist)
        //                        .font(.title3)
        //                        .foregroundStyle(.gray)
        //                        .lineLimit(1)
        //                }
        //                .frame(maxWidth: .infinity, alignment: .leading)
        //                .padding(.horizontal, 30)
        //
        //                VStack(spacing: 5) {
        //                    if #available(iOS 26.0, *), #available(macOS 26.0, *) {
        //                         Slider(
        //                             value: Binding(
        //                                 get: { playerViewModel.currentTime },
        //                                 set: { playerViewModel.seek(to: $0) }
        //                             ),
        //                             in: 0...(playerViewModel.duration > 0 ? playerViewModel.duration : 1)
        //                         )
        //                         .tint(.red)
        //                         .sliderThumbVisibility(.hidden)
        //                    } else {
        //                         Slider(
        //                             value: Binding(
        //                                 get: { playerViewModel.currentTime },
        //                                 set: { playerViewModel.seek(to: $0) }
        //                             ),
        //                             in: 0...(playerViewModel.duration > 0 ? playerViewModel.duration : 1)
        //                         )
        //                         .tint(.red)
        //                    }
        //
        //                    HStack {
        //                        Text(formatTime(playerViewModel.currentTime))
        //                        Spacer()
        //                        Text(formatTime(playerViewModel.duration))
        //                    }
        //                    .font(.caption)
        //                    .foregroundStyle(.gray)
        //                }
        //                .padding(.horizontal, 30)
        //
        //                HStack(spacing: 50) {
        //                    Button {
        //                    } label: {
        //                        Image(systemName: "backward.fill")
        //                    }
        //
        //                    Button {
        //                        playerViewModel.togglePlayPause()
        //                    } label: {
        //                        Image(systemName: playerViewModel.player.timeControlStatus == .playing ? "pause.circle.fill" : "play.circle.fill")
        //                            .font(.system(size: 70))
        //                    }
        //
        //                    Button {
        //                    } label: {
        //                        Image(systemName: "forward.fill")
        //                    }
        //                }
        //                .foregroundStyle(.white)
        //                .font(.largeTitle)
        //                .padding(.bottom, 50)
        //            }
        //        }
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
        Image(.notPlaying)
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
    
    var artwork: some View {
        GeometryReader { geometry in
            VStack {
                if properties.isPlayerExpanded {
                ZStack {
//                    Image(.notPlaying)
//                        .resizable()
//                        .aspectRatio(1, contentMode: .fit)
//                        .clipShape(.rect(cornerRadius: 12))
//                        .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 4)
//                        .matchedGeometryEffect(id: "Artwork", in: namespace, properties: .frame, anchor: .center)
//                        .transition(.offset(y: 1))
                    
                    VideoPlayer(player: playerViewModel.player)
                        .matchedGeometryEffect(id: "Artwork", in: namespace, properties: .frame)
                        .transition(.offset(y: 1))
                        .frame(width: 300, height: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(radius: 20)
//                        .onTapGesture(count: 2) {
//                            withAnimation {
//                                playerMode = (playerMode == .video) ? .audio : .video
//                            }
//                        }
                }
                .frame(width: geometry.size.width, height: geometry.size.width)
            }
        }
        .frame(width: geometry.size.width, height: geometry.size.width)
        }
        .padding(.horizontal, 15)
    }
    
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
        .padding(.top, 15)
        .padding(.horizontal, 15)
    }
    
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
        .padding(.bottom, safeArea.bottom)
    }
    
    func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite else { return "0:00" }
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}
