//
//  Player.swift
//  cisum
//
//  Created by Aarav Gupta on 09/03/24.
//

import SwiftUI
import WebKit

struct Player: View {
    var videoID: String
    let accentColor = Color(red: 0.976, green: 0.176, blue: 0.282, opacity: 0.3)
    @State private var activeTab: songorvideo = .song
    @Binding var expandPlayer: Bool
    var animation: Namespace.ID
    @State private var animateContent: Bool = false
    @State private var offsetY: CGFloat = 0
    @State private var liked: Bool = false
    @State private var isPlaying: Bool = false
    @State private var transparency: Double = 0.0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundLayer(size: geometry.size)
                contentLayer(size: geometry.size, safeArea: geometry.safeAreaInsets)
            }
            .contentShape(Rectangle())
            .offset(y: offsetY)
            .gesture(dragGesture(size: geometry.size))
            .ignoresSafeArea(.container, edges: .all)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.35)) {
                    animateContent = true
                }
            }
        }
    }

    //MARK: This code here is for the background of the Player
    private func backgroundLayer(size: CGSize) -> some View {
        RoundedRectangle(cornerRadius: animateContent ? deviceCornerRadius : 0, style: .continuous)
            .fill(.ultraThickMaterial)
            .overlay(content: {
                RoundedRectangle(cornerRadius: animateContent ? deviceCornerRadius : 0, style: .continuous)
                    .fill(.ultraThickMaterial)
                    .opacity(animateContent ? 1 : 0)
            })
            .overlay(alignment: .top) {
                MusicInfo(expandPlayer: $expandPlayer, animation: animation)
                    .allowsHitTesting(false)
                    .opacity(animateContent ? 0 : 1)
            }
            .matchedGeometryEffect(id: "Background", in: animation, isSource: false)
    }

    //MARK: This is for the entire content inside the Player
    private func contentLayer(size: CGSize, safeArea: EdgeInsets) -> some View {
        VStack(spacing: 15) {
            tabSelectionView
                .frame(width: 210, height: 35)
                .opacity(animateContent ? 1 : 0)
                .offset(y: animateContent ? 0 : size.height)

            artworkPlayerView
                .matchedGeometryEffect(id: "Album Cover", in: animation, isSource: false)
                .offset(x: isPlaying ? 0 : 47, y: isPlaying ? 0 : 47)
                .frame(width: 343, height: 343)
                .padding(.top, 5)
                .padding(.vertical, size.height < 700 ? 10 : 15)

            playerButtons(size: size)
                .offset(y: animateContent ? 0 : size.height)
        }
        .padding(.top, safeArea.top + (safeArea.bottom == 0 ? 10 : 0))
        .padding(.bottom, safeArea.bottom == 0 ? 10 : safeArea.bottom)
        .padding(.horizontal, 25)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .clipped()
    }

    private var tabSelectionView: some View {
        VStack(spacing: 15) {
            SongOrVideo(tabs: songorvideo.allCases, activeTab: $activeTab, height: 35, font: .body, activeTint: .primary, inActiveTint: .gray.opacity(0.5)) { size in
                RoundedRectangle(cornerRadius: 30)
                    .fill(accentColor)
                    .frame(height: size.height)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
//            .background {
//                RoundedRectangle(cornerRadius: 30)
//                    .fill(.ultraThinMaterial)
//                    .ignoresSafeArea()
//            }
            .padding(.horizontal, 15)
            .padding(.vertical, 15)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    //MARK: For the box in the middle
    private var artworkPlayerView: some View {
        GeometryReader { _ in
            APIPlayer(videoID: videoID)
                .edgesIgnoringSafeArea(.all)
                .frame(width: isPlaying ? 343 : 250, height: isPlaying ? 343 : 250)
                .clipShape(RoundedRectangle(cornerRadius: animateContent ? 15 : 5, style: .continuous))
        }
    }

    //MARK: for the buttons below
    private func playerButtons(size: CGSize) -> some View {
        VStack(spacing: size.height * 0.04) {
            GeometryReader { proxy in
                let spacing = proxy.size.height * 0.04

                VStack(spacing: spacing) {
                    VStack(spacing: spacing) {
                        HStack(alignment: .center, spacing: 15) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Song Name")
                                    .font(.title3)
                                    .fontWeight(.semibold)

                                Text("Artist")
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Button {
                                liked.toggle()
                            } label: {
                                Image(liked ? "liked" : "unliked")
                                    .foregroundColor(.white)
                                    .font(.title)
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
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .padding(.leading, 12)
                            }
                        }

                        //Song Duration Slider
                        Capsule()
                            .fill(.gray)
                            .frame(height: 8)
                            .padding(.top, spacing)

                        //Song Duration Label
                        HStack {
                            Text("--:--")
                                .font(.caption)

                            Spacer(minLength: 0)

                            Text("--:--")
                                .font(.caption)
                        }
                        .foregroundColor(.gray)
                    }
                    .frame(height: proxy.size.height / 2.5, alignment: .top)

                    //MARK: Playback Controls
                    HStack(spacing: proxy.size.width * 0.18) {
                        BackwardButton()

                        Button {
                            //Play/Pause Function
                            isPlaying.toggle()
                            transparency = 0.6
                            withAnimation(.easeOut(duration: 0.2)) {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    transparency = 0.0
                                }
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .frame(width: 80, height: 80)
                                    .opacity(transparency)
                                Image(systemName: "pause.fill")
                                    .font(.system(size: 50))
                                    .scaleEffect(isPlaying ? 1 : 0)
                                    .opacity(isPlaying ? 1 : 0)
                                    .animation(.interpolatingSpring(stiffness: 170, damping: 15), value: isPlaying)

                                Image(systemName: "play.fill")
                                    .font(.system(size: 50))
                                    .scaleEffect(isPlaying ? 0 : 1)
                                    .opacity(isPlaying ? 0 : 1)
                                    .animation(.interpolatingSpring(stiffness: 170, damping: 15), value: isPlaying)
                            }
                        }

                        ForwardButton()
                    }
                    .padding(.top, -15)
                    .foregroundColor(.white)
                    .frame(maxHeight: .infinity)

                    //MARK: Volume Controls
                    VStack(spacing: spacing) {
                        HStack(spacing: 15) {
                            Image(systemName: "speaker.fill")
                                .foregroundColor(.gray)

                            Capsule()
                                .fill(.gray)
                                .environment(\.colorScheme, .light)
                                .frame(height: 8)

                            Image(systemName: "speaker.wave.3.fill")
                                .foregroundColor(.gray)
                        }

                        HStack(alignment: .top, spacing: proxy.size.width * 0.18) {
                            Button(action: {

                            }) {
                                Image(systemName: "quote.bubble")
                                    .font(.title2)
                            }
                            .padding(.top, 3)

                            AirPlayButton()
                                .frame(width: 50, height: 50)
                                .padding(.top, -13)
                                .padding(.horizontal, 25)

                            Button(action: {

                            }) {
                                Image(systemName: "list.bullet")
                                    .font(.title2)
                            }
                            .padding(.top, 3)
                        }
                        .foregroundColor(.white)
                        .blendMode(.overlay)
                        .padding(.top, spacing)
                    }
                    .padding(.bottom, 30)
                    .frame(height: proxy.size.height / 2.5, alignment: .bottom)
                }
            }
        }
    }


    private func dragGesture(size: CGSize) -> some Gesture {
        DragGesture()
            .onChanged({ value in
                let translationY = value.translation.height
                offsetY = (translationY > 0 ? translationY : 0)
            })
            .onEnded({ value in
                withAnimation(.easeInOut(duration: 0.3)) {
                    if offsetY > size.height * 0.4 {
                        expandPlayer = false
                        animateContent = false
                    } else {
                        offsetY = .zero
                    }
                }
            })
    }
}

extension View {
  var deviceCornerRadius: CGFloat {
    let key = "_displayCornerRadius"
    if let screen = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.screen {
      if let cornerRadius = screen.value(forKey: key) as? CGFloat {
        return cornerRadius
      }

      return 0
    }

    return 0
  }
}



#Preview {
    Main(videoID: "")
    .preferredColorScheme(.dark)
}
