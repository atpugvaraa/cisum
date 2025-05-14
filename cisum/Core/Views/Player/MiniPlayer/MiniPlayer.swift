//
//  MiniPlayer.swift
//  cisum
//
//  Created by Aarav Gupta (github.com/atpugvaraa) on 10/05/25.
//

import SwiftUI

struct MiniPlayer: View {
    var namespace: Namespace.ID
    
    let player: Player
    let properties: PlayerProperties
    
    var body: some View {
        HStack(spacing: 12) {
            artwork
            
            Text(player.currentSong)
            
            Spacer(minLength: 0)
            
            playButton
        }
        .padding(.leading, 6)
        .padding(.trailing, 8)
        .frame(height: 55)
        .contentShape(.rect)
        .onTapGesture {
            withAnimation(.smooth(duration: 0.3, extraBounce: 0)) {
                properties.expandPlayer = true
            }
            
            /// Resizing window when opening player
            UIView.animate(withDuration: 0.3) {
                properties.resizeWindow(0.1)
            }
        }
        .overlay {
            cisumMiniPlayerProgress(currentTime: .constant(60), inRange: 0...240)
        }
    }
    
    var artwork: some View {
        ZStack {
            if !properties.expandPlayer {
                player.artwork
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipShape(.rect(cornerRadius: 10))
                    .matchedGeometryEffect(id: "Artwork", in: namespace)
            }
        }
        .frame(width: 45, height: 45)
    }
    
    var playButton: some View {
        Button {
            //            player.togglePlay()
            properties.transparency = 0.6
            withAnimation(.easeOut(duration: 0.2)) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    properties.transparency = 0.0
                }
            }
        } label: {
            ZStack {
                Circle()
                    .frame(width: 35, height: 35)
                    .opacity(properties.transparency)
                #warning("uncomment this when player observable is written")
//                    Image(systemName: "pause.fill")
//                        .font(.title2)
                //                    .scaleEffect(player.isPlaying ? 1 : 0)
                //                    .opacity(player.isPlaying ? 1 : 0)
                //                    .animation(.interpolatingSpring(stiffness: 170, damping: 15), value: player.isPlaying)
                Image(systemName: "play.fill")
                    .font(.title2)
                //                    .scaleEffect(player.isPlaying ? 0 : 1)
                //                    .opacity(player.isPlaying ? 0 : 1)
                //                    .animation(.interpolatingSpring(stiffness: 170, damping: 15), value: player.isPlaying)
            }
        }
        .font(.title3)
        .foregroundStyle(Color.primary)
        .padding(.trailing, 5)
    }
}
