//
//  Playlist.swift
//  cisum
//
//  Created by Aarav Gupta on 09/03/24.
//

import SwiftUI
import UIKit

struct Playlist: View {
    @State private var isPlaying = false
    @State private var liked = false
    
    func getOffsetY(reader: GeometryProxy) -> CGFloat {
        let offsetY: CGFloat = -reader.frame(in: .named("scrollView")).minY
        if offsetY < 0 {
            return offsetY / 1.3
        }
        return offsetY
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                // Album Cover Art
                GeometryReader { reader in
                    let offsetY = getOffsetY(reader: reader)
                    let height: CGFloat = (reader.size.height - offsetY) + offsetY / 3
                    let minHeight: CGFloat = 120
                    let opacity = (height - minHeight) / (reader.size.height - minHeight)
                    
                    ZStack {
                        LinearGradient(gradient: Gradient(colors: [Color.white, Color.black]), startPoint: .top, endPoint: .bottom)
                            .scaleEffect(6)
                        
                        Image("Image")
                            .resizable()
                            .frame(width: height, height: height)
                            .offset(y: offsetY)
                            .opacity(Double(opacity))
                    }
                    .frame(width: reader.size.width)
                }
                .frame(height: 250)
                
                HStack {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Spring Skies")
                            .font(.title)
                            .bold()
                        
                        HStack {
                            Image("Image")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                            
                            Text("prower")
                                .font(.title2)
                                .bold()
                        }
                        
                        Text("Album • 2024")
                        
                        HStack(spacing: 30) {
                            Button {
                                liked.toggle()
                            } label: {
                                Image(liked ? "liked" : "unliked")
                                    .foregroundColor(.white)
                            }
                            
                            Menu {
                                Button(action: {
                                    // Action for Add to Playlist button
                                }) {
                                    Label("Add to Playlist", systemImage: "plus")
                                }
                                
                                Button(action: {
                                    // Action for Downloading Song
                                }) {
                                    Label("Download", systemImage: "arrow.down.circle")
                                }
                                
                                Button(action: {
                                    // Action for Sharing the Song
                                }) {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                }
                            } label: {
                                Label ("", systemImage: "ellipsis")
                                    .font(.system(size: 21))
                                    .foregroundColor(.white)
                                    .padding(.vertical, 12)
                                    .padding(.bottom, 8)
                            }
                        }
                        
                    }
                    .foregroundColor(.black)

                    Spacer()

                    Button {
                        isPlaying.toggle()
                    } label: {
                        ZStack {
                            Circle()
                                .foregroundColor(.black.opacity(0.5))
                            Image(systemName: "pause.fill")
                                .font(.system(size: 25))
                                .scaleEffect(isPlaying ? 1 : 0)
                                .opacity(isPlaying ? 1 : 0)
                                .foregroundColor(.black.opacity(0.85))
                                .animation(.interpolatingSpring(stiffness: 170, damping: 15), value: isPlaying)
                            Image(systemName: "play.fill")
                                .font(.system(size: 25))
                                .scaleEffect(isPlaying ? 0 : 1)
                                .opacity(isPlaying ? 0 : 1)
                                .foregroundColor(.black.opacity(0.85))
                                .animation(.interpolatingSpring(stiffness: 170, damping: 15), value: isPlaying)
                        }
                        .frame(width: 60, height: 60)
                    }
                }
                .padding(.horizontal)
            }
            .coordinateSpace(name: "scrollView")
            .background(Color.white.ignoresSafeArea())
        }
    }
}

#Preview {
  Playlist()
}
