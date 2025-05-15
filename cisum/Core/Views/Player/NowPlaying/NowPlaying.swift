//
//  NowPlaying.swift
//  cisum
//
//  Created by Aarav Gupta (github.com/atpugvaraa) on 10/05/25.
//

import SwiftUI

struct NowPlaying: View {
    var namespace: Namespace.ID
    
    let size: CGSize
    let safeArea: EdgeInsets
    let player: Player
    let properties: PlayerProperties
    
    var body: some View {
        VStack(spacing: 12) {
            header
            
            artwork
            
            songInfo
            
            playerControls
        }
        .padding(.top, 10)
        .padding(.vertical, 20)
        .padding(.horizontal, 15)
        .padding(.top, safeArea.top)
        .animation(.smooth(duration: 0.35), value: properties.expandPlayer)
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
                        properties.expandPlayer = false
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
                if properties.expandPlayer {
                ZStack {
                    Image(.notPlaying)
                        .resizable()
                        .aspectRatio(1, contentMode: .fit)
                        .clipShape(.rect(cornerRadius: 12))
                        .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 4)
                        .matchedGeometryEffect(id: "Artwork", in: namespace, properties: .frame, anchor: .center)
                        .transition(.offset(y: 1))
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
                //                Text(player.currentSong.title)
                Text(player.currentSong)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                
                //                Text(player.currentSong.artist)
                Text("Unknown")
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
                footer
            }
            .padding(.horizontal, 15)
        }
    }
    
    var footer: some View {
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
}
