//
//  Player.swift
//  cisum
//
//  Created by Aarav Gupta on 09/03/24.
//

import SwiftUI
import YouTubePlayerKit

struct Player: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    var videoID: String
    var animation: Namespace.ID
    var currentThumbnailURL: String

    // State variables
    @State private var activeTab: songorvideo = .song
    @State private var expandPlayer: Bool = false
    @State private var animateContent: Bool = false
    @State private var offsetY: CGFloat = 0
    @State private var liked: Bool = false
    @State private var isPlaying: Bool = true
    @State private var transparency: Double = 0.0
    @State private var playerDuration: TimeInterval = 0
    @State private var volume: Double = 0
    @State private var color: Color = .white

    // Define the accent color
    private let accentColor = Color(red: 0.976, green: 0.176, blue: 0.282, opacity: 0.3)
    private var normalFillColor: Color { color.opacity(0.5) }
    private var emptyColor: Color { color.opacity(0.3) }

    // Constants for max duration and volume
    private let maxDuration: TimeInterval = 240
    private let maxVolume: Double = 1

    @State private var player: YouTubePlayer?

    var body: some View {
        NavigationView {
            GeometryReader {
                let size = $0.size
                let safeArea = $0.safeAreaInsets

                ZStack {
                    dynamicBackground
                        .padding(.trailing, 3)
                        .matchedGeometryEffect(id: "Background", in: animation)

                    VStack(spacing: 15) {
                        songorvideoTab
                        ZStack {
                            if let player = player {
                                YouTubePlayerView(player)
                                .allowsHitTesting(false)
                                    .frame(width: isPlaying ? 343 : 250, height: isPlaying ? 343 : 250)
                                    .clipShape(RoundedRectangle(cornerRadius: animateContent ? 15 : 5, style: .continuous))
                                    .animation(.easeInOut(duration: 0.3), value: isPlaying)
                            }
                            albumArtwork
                                .matchedGeometryEffect(id: "Album Cover", in: animation, isSource: false)
                                .offset(x: isPlaying ? 0 : 47, y: isPlaying ? 0 : 47)
                                .frame(width: 343, height: 343)
                                .padding(.vertical, size.height < 700 ? 10 : 15)
                        }
                        .padding(.top, 5)

                        playerButtons(size: size)
                            .offset(y: animateContent ? 0 : size.height)
                    }
                    .padding(.top, safeArea.top + (safeArea.bottom == 0 ? 10 : 0))
                    .padding(.bottom, safeArea.bottom == 0 ? 10 : safeArea.bottom)
                    .padding(.horizontal, 25)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .clipped()
                }
                .contentShape(Rectangle())
                .offset(y: offsetY)
                .gesture(dragGesture(size: size))
                .ignoresSafeArea(.container, edges: .all)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        animateContent = true
                    }

                    // Initialize the player here because `viewModel` is now available
                    player = YouTubePlayer(
                        source: .video(id: viewModel.currentVideoID ?? videoID),
                        configuration: .init(
                            autoPlay: true,
                            showCaptions: false,
                            showControls: false,
                            showFullscreenButton: false,
                            showAnnotations: false,
                            loopEnabled: false,
                            useModestBranding: false,
                            showRelatedVideos: false
                        )
                    )
                }
            }
        }
    }
  
  private var dynamicBackground: some View {
    GeometryReader {
      let size = $0.size
      
      let url = URL(string: currentThumbnailURL)
      AnyView(
        AsyncImage(url: url) { phase in
          switch phase {
          case .success(let image):
            image
              .resizable()
              .scaledToFill()
              .edgesIgnoringSafeArea(.all)
              .frame(width: size.width, height: size.height)
              .clipShape(RoundedRectangle(cornerRadius: animateContent ? deviceCornerRadius : 0, style: .continuous))
              .overlay(content: {
                RoundedRectangle(cornerRadius: animateContent ? deviceCornerRadius : 0, style: .continuous)
                  .fill(.ultraThinMaterial)
                  .opacity(animateContent ? 1 : 0)
              })
          case .failure, .empty:
            Image("musicnote")
              .resizable()
              .edgesIgnoringSafeArea(.all)
              .scaledToFill()
              .frame(width: size.width, height: size.height)
              .clipShape(RoundedRectangle(cornerRadius: animateContent ? deviceCornerRadius : 0, style: .continuous))
              .overlay(content: {
                RoundedRectangle(cornerRadius: animateContent ? deviceCornerRadius : 0, style: .continuous)
                  .fill(.bg)
                  .opacity(animateContent ? 1 : 0)
              })
          @unknown default:
            EmptyView()
          }
        }
      )
    }
    .overlay(alignment: .top) {
      MusicInfo(expandPlayer: $viewModel.expandPlayer, animation: animation, currentTitle: viewModel.currentTitle ?? "Not Playing", currentArtist: viewModel.currentArtist ?? "", currentThumbnailURL: viewModel.currentThumbnailURL ?? "musicnote")
        .allowsHitTesting(false)
        .opacity(animateContent ? 0 : 1)
    }
  }
  
  private var songorvideoTab: some View {
    VStack(spacing: 15) {
      SongOrVideo(tabs: songorvideo.allCases, activeTab: $activeTab, height: 35, font: .body, activeTint: .primary, inActiveTint: .secondary) { size in
        RoundedRectangle(cornerRadius: 30)
          .fill(accentColor)
          .frame(height: size.height)
          .frame(maxHeight: .infinity, alignment: .bottom)
      }
      .padding(.horizontal, 15)
      .padding(.vertical, 15)
      .toolbarBackground(.hidden, for: .navigationBar)
    }
    .frame(width: 210, height: 35)
    .opacity(animateContent ? 1 : 0)
    .offset(y: animateContent ? 0 : 343)
  }
  
  private var albumArtwork: some View {
    GeometryReader { _ in
      if activeTab == .song {
          albumArt(isPlaying: isPlaying, animateContent: animateContent, currentThumbnailURL: viewModel.currentThumbnailURL ?? "musicnote")
        .frame(width: isPlaying ? 343 : 250, height: isPlaying ? 343 : 250)
        .clipShape(RoundedRectangle(cornerRadius: animateContent ? 15 : 5, style: .continuous))
        .animation(.easeInOut(duration: 0.3), value: isPlaying)
      }
    }
  }
  
  func albumArt(isPlaying: Bool, animateContent: Bool, currentThumbnailURL: String) -> some View {
    if let url = URL(string: currentThumbnailURL) {
      return AnyView(
        AsyncImage(url: url) { phase in
          switch phase {
          case .success(let image):
            image
              .resizable()
              .scaledToFit()
              .frame(width: isPlaying ? 343 : 250, height: isPlaying ? 343 : 250)
              .clipShape(RoundedRectangle(cornerRadius: animateContent ? 15 : 5, style: .continuous))
              .animation(.easeInOut(duration: 0.3), value: isPlaying) // Add animation for smooth expand
          case .failure, .empty:
            Image("musicnote")
              .resizable()
              .scaledToFit()
              .frame(width: isPlaying ? 343 : 250, height: isPlaying ? 343 : 250)
              .clipShape(RoundedRectangle(cornerRadius: animateContent ? 15 : 5, style: .continuous))
              .animation(.easeInOut(duration: 0.3), value: isPlaying) // Add animation for smooth expand
          @unknown default:
            EmptyView()
          }
        }
      )
    } else {
      return AnyView(
        Image("musicnote")
          .resizable()
          .scaledToFit()
          .frame(width: isPlaying ? 343 : 250, height: isPlaying ? 343 : 250)
          .clipShape(RoundedRectangle(cornerRadius: animateContent ? 15 : 5, style: .continuous))
          .animation(.easeInOut(duration: 0.3), value: isPlaying) // Add animation for smooth expand
      )
    }
  }
  
  private func playerButtons(size: CGSize) -> some View {
    VStack(spacing: size.height * 0.04) {
      GeometryReader {
        let size = $0.size
        let spacing = size.height * 0.04
        
        VStack(spacing: spacing) {
          VStack(spacing: spacing) {
            HStack(alignment: .center, spacing: 15) {
              VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.currentTitle ?? "Not Playing")
                  .font(.title3)
                  .fontWeight(.semibold)
                
                Text(viewModel.currentArtist ?? "Artist")
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
              .onTapGesture {
                Toast.shared.present(title: liked ? "Favourited" : "Unfavourited", isUserInteractionEnabled: false, timing: .short)
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
                  .padding(.leading, 12)
                  .padding(.trailing, -9)
              }
            }
            
            //Song Duration Slider
            MusicProgressSlider(value: $playerDuration, inRange: TimeInterval.zero...maxDuration, activeFillColor: color, fillColor: normalFillColor, emptyColor: emptyColor, height: 32) { started in
              
            }
            .padding(.top, spacing)
          }
          .frame(height: size.height / 2.5, alignment: .top)
          
          //MARK: Playback Controls
          HStack(spacing: size.width * 0.18) {
            BackwardButton()
            
            Button {
              if isPlaying == false {
                player!.play()
              } else if isPlaying == true {
                player!.pause()
              }
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
            .padding(.horizontal, -25)
            ForwardButton()
          }
          .padding(.top, -15)
          .foregroundColor(.white)
          .frame(maxHeight: .infinity)
          
          //MARK: Volume Controls
          VStack(spacing: spacing) {
            VolumeSlider(value: $volume, inRange: 0...maxVolume, activeFillColor: color, fillColor: normalFillColor, emptyColor: emptyColor, height: 8) { started in }
            
            HStack(alignment: .top, spacing: size.width * 0.18) {
              Button(action: {
                
              }) {
                Image(systemName: "quote.bubble")
                  .font(.title2)
              }
              .padding(.top, 2.5)
              
              AirPlayButton()
                .frame(width: 50, height: 50)
                .padding(.top, -10)
                .padding(.horizontal, 25)
              
              Button(action: {
                
              }) {
                Image(systemName: "list.bullet")
                  .font(.title2)
              }
              .padding(.top, 5)
            }
            .foregroundColor(.white)
            .blendMode(.overlay)
            .padding(.top, spacing)
          }
          .padding(.bottom, 30)
          .frame(height: size.height / 2.5, alignment: .bottom)
        }
      }
    }
  }
  
  private func dragGesture(size: CGSize) -> some Gesture {
    DragGesture()
      .onChanged { value in
        // Calculate the translation along the Y-axis
        let translationY = value.translation.height
        // Limit the upward translation
        offsetY = max(translationY, 0)
      }
      .onEnded { value in
        // Determine if the player should collapse
        let shouldCollapse = offsetY > size.height * 0.3
        
        // Use a smooth easing function and adjust the duration for a better transition
        withAnimation(shouldCollapse ? .easeInOut(duration: 0.5) : .spring()) {
          if shouldCollapse {
            // Collapse the player
            viewModel.expandPlayer = false
            animateContent = false
            offsetY = 0 // Reset the offset
          } else {
            // Return the player to its original position
            offsetY = 0
          }
        }
      }
  }
}

#Preview {
  Main(videoID: "")
    .preferredColorScheme(.dark)
}
