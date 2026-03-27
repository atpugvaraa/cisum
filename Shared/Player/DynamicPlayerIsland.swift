//
//  DynamicPlayerIsland.swift
//  cisum
//
//  Created by Aarav Gupta on 13/03/26.
//

import Kingfisher
import SwiftUI

struct DynamicPlayerIsland: View {
#if os(iOS)
    var namespace: Namespace.ID
    
    @State private var properties = PlayerProperties.shared
    @Environment(PlayerViewModel.self) private var playerViewModel

    #if DEBUG
    @ObserveInjection var forceRedraw
    #endif

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                ZStack {
                    RoundedRectangle(cornerRadius: 50)
                        .fill(.clear)
                        .glassEffect(.identity)
                        .matchedGeometryEffect(id: "GLASS", in: namespace)
                        .frame(height: 48)
                        .overlay {
                            HStack(spacing: 12) {
                                KFImage(playerViewModel.currentImageURL)
                                    .matchedGeometryEffect(id: "Artwork", in: namespace)
                                    .frame(width: 40, height: 40)
                                    .aspectRatio(contentMode: .fit)
                                    .clipShape(.circle)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(playerViewModel.currentTitle)
                                        .fontWeight(.semibold)
                                    Text(playerViewModel.currentArtist)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                HStack(spacing: 14) {
                                    Image(systemName: "backward.fill")
                                    Image(systemName: "play.fill")
                                    Image(systemName: "forward.fill")
                                }
                                .font(.title3)
                                .fontWeight(.bold)
                            }
                            .padding(.leading, 5)
                            .padding(.trailing, 10)
                        }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            } else {
                HStack(spacing: 12) {
                    artwork
                    
                    Text(playerViewModel.currentTitle)
                    
                    Spacer(minLength: 0)
                    
                    playButton
                }
                .padding(.leading, 3)
                .padding(.trailing, 4)
                .frame(height: 44)
                .contentShape(.rect)
                .onTapGesture {
                    properties.expandPlayer()
                }
            }
        }
        .enableInjection()
    }
#elseif os(macOS)
    @State private var isHovered: Bool = false
    @Namespace private var namespace

    #if DEBUG
    @ObserveInjection var forceRedraw
    #endif

    var body: some View {
        ZStack {
            if isHovered {
                if #available(macOS 26.0, *) {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.clear)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
                        .matchedGeometryEffect(id: "GLASS", in: namespace)
                        .frame(height: 180)
                        .overlay {
                            VStack {
                                HStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .matchedGeometryEffect(id: "Artwork", in: namespace)
                                        .frame(width: 74, height: 74)
                                    VStack(alignment: .leading) {
                                        Text("Now Playing")
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                        Text("Artist")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding()
                                
                                Spacer()
                                
                                HStack {
                                    Image(systemName: "backward.fill")
                                    Image(systemName: "play.fill")
                                    Image(systemName: "forward.fill")
                                }
                                .font(.title)
                                .padding()
                            }
                        }
                }
            } else {
                if #available(macOS 26.0, *) {
                    RoundedRectangle(cornerRadius: 40)
                        .fill(.secondary.opacity(0.06))
                        .glassEffect(.regular)
                        .matchedGeometryEffect(id: "GLASS", in: namespace)
                        .frame(height: 70)
                        .overlay {
                            HStack {
                                Circle()
                                    .matchedGeometryEffect(id: "Artwork", in: namespace)
                                    .frame(width: 44, height: 44)
                                Text("Now Playing")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            .padding(12)
                        }
                }
            }
        }
        .padding()
        .onHover { hovering in
            withAnimation(.bouncy) {
                isHovered = hovering
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .enableInjection()
    }
#endif

#if os(iOS)
    var artwork: some View {
        ZStack {
            if !properties.isPlayerExpanded {
                KFImage(playerViewModel.currentImageURL)
                    .matchedGeometryEffect(id: "Artwork", in: namespace)
                    .frame(width: 40, height: 40)
                    .aspectRatio(contentMode: .fit)
                    .clipShape(.circle)
            }
        }
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
#endif
}
