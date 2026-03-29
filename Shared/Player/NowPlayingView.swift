//
//  NowPlayingView.swift
//  cisum
//
//  Created by Aarav Gupta on 05/12/25.
//

#if os(iOS)
import SwiftUI

struct NowPlayingView: View {
    @Environment(PlayerViewModel.self) var playerViewModel

    var namespace: Namespace.ID
    @State private var properties = PlayerProperties.shared
    
#if DEBUG
    @ObserveInjection var forceRedraw
#endif

    var body: some View {
        ZStack {
            if #available(iOS 26.0, *) {
                PlayerExpandedBackground(isExpanded: true, includesCollapsedBarLayer: false)
                    .ignoresSafeArea()
                
                playerView
            } else {
                playerView
                    .safeAreaPadding(.top)
                    .safeAreaPadding(.bottom)
                    .ignoresSafeArea()
            }
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
            Color.clear
            .frame(width: geometry.size.width, height: geometry.size.width)
            .accessibilityHidden(true)
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
                    .foregroundColor(.white.opacity(0.8))
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
#if os(iOS)
                    cisumMusicProgressScrubber(
                        currentTime: playerViewModel.currentTime,
                        duration: playerViewModel.duration,
                        onSeek: { newTime in
                            playerViewModel.seek(to: newTime)
                        }
                    )
#endif
                }
                .frame(height: 30)
                
                Spacer(minLength: 0)
                
                // Buttons
                HStack(spacing: size.width * 0.18) {
                    cisumBackwardButton()
                    
                    cisumPlayButton()
                        .disabled(playerViewModel.currentVideoId == nil)
                    
                    cisumForwardButton()
                }
                .foregroundColor(.white)
                
                Spacer(minLength: 0)
                
                VStack {
#if os(iOS)
                    cisumVolumeSlider()
#endif
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
            
            AirPlayButton(activeTintColor: playerViewModel.currentAccentColor.uiColor)
                .frame(width: 48, height: 48)
                .padding(.top, -13)
            
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
#endif
