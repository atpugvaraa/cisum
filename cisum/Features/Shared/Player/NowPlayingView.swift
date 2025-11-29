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
    
    // New State for Mode Switching
    enum PlayerMode { case video, audio }
    @State private var playerMode: PlayerMode = .video
    
    #if DEBUG
    @ObserveInjection var forceRedraw
    #endif

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background Gradient
                LinearGradient(colors: [.red.opacity(0.8), .black], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Grab Handle
                    Capsule()
                        .frame(width: 40, height: 5)
                        .foregroundStyle(.white.opacity(0.3))
                        .padding(.top, 50)
                        .onTapGesture { dismiss() }
                    
                    Spacer()
                    
                    // MARK: - Player View (using native AVPlayer)
                    VideoPlayer(player: playerViewModel.player)
                        .frame(width: 300, height: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(radius: 20)
                        .onTapGesture(count: 2) {
                            withAnimation {
                                playerMode = (playerMode == .video) ? .audio : .video
                            }
                        }
                    
                    // Mode Switcher (Optional, but good for testing)
                    Picker("Mode", selection: $playerMode) {
                        Image(systemName: "video.fill").tag(PlayerMode.video)
                        Image(systemName: "music.note").tag(PlayerMode.audio)
                    }
                        .pickerStyle(.segmented)
                        .frame(width: 150)
                        .padding(.top, 10)
                    
                    Spacer()
                    
                    // Song Info (Powered by VM Metadata)
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(playerViewModel.currentTitle)
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            
                            if playerViewModel.isExplicit {
                                Text("E")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.white.opacity(0.8))
                                    .padding(4)
                                    .background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
                            }
                        }
                        
                        Text(playerViewModel.currentArtist)
                            .font(.title3)
                            .foregroundStyle(.gray)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 30)
                    
                    // Progress
                    VStack(spacing: 5) {
                        // Slider Binding
                        if #available(iOS 26.0, *), #available(macOS 26.0, *) {
                             Slider(
                                 value: Binding(
                                     get: { playerViewModel.currentTime },
                                     set: { playerViewModel.seek(to: $0) }
                                 ),
                                 in: 0...(playerViewModel.duration > 0 ? playerViewModel.duration : 1)
                             )
                             .tint(.red)
                             .sliderThumbVisibility(.hidden)
                        } else {
                            // Fallback Slider
                             Slider(
                                 value: Binding(
                                     get: { playerViewModel.currentTime },
                                     set: { playerViewModel.seek(to: $0) }
                                 ),
                                 in: 0...(playerViewModel.duration > 0 ? playerViewModel.duration : 1)
                             )
                             .tint(.red)
                        }
                        
                        HStack {
                            Text(formatTime(playerViewModel.currentTime))
                            Spacer()
                            Text(formatTime(playerViewModel.duration))
                        }
                        .font(.caption)
                        .foregroundStyle(.gray)
                    }
                    .padding(.horizontal, 30)
                    
                    // Controls
                    HStack(spacing: 50) {
                        Button { } label: {
                            Image(systemName: "backward.fill")
                        }
                        
                        Button {
                            playerViewModel.togglePlayPause()
                        } label: {
                            // Observe the player directly for instant status updates
                            Image(systemName: playerViewModel.player.timeControlStatus == .playing ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 70))
                        }
                        
                        Button { } label: {
                            Image(systemName: "forward.fill")
                        }
                    }
                    .foregroundStyle(.white)
                    .font(.largeTitle)
                    .padding(.bottom, 50)
                }
            }
        }
        // React to mode changes by reloading the stream
        .onChange(of: playerMode) { _, newMode in
            print("🔄 Switching Mode to: \(newMode)")
            playerViewModel.reloadCurrentVideo(preferAudio: newMode == .audio)
        }
        .enableInjection()
    }
    
    func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite else { return "0:00" }
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}

#Preview {
    NowPlayingView()
        .environment(PlayerViewModel())
}
