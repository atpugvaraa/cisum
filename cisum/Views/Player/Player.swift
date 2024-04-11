//
//  Player.swift
//  cisum
//
//  Created by Aarav Gupta on 09/03/24.
//

import SwiftUI

struct Player: View {
  @EnvironmentObject var viewModel: PlayerViewModel
  var videoID: String
  var animation: Namespace.ID
  var currentThumbnailURL: String
  @State private var activeTab: songorvideo = .song
  @State private var expandPlayer: Bool = false
  @State private var animateContent: Bool = false
  @State private var offsetY: CGFloat = 0
  @State private var liked: Bool = false
  @State private var isPlaying: Bool = false
  @State private var transparency: Double = 0.0
  @State private var playerDuration: TimeInterval = 0
  @State private var volume: Double = 0
  @State private var color: Color = .white
  private let accentColor = Color(red: 0.976, green: 0.176, blue: 0.282, opacity: 0.3)
  private var normalFillColor: Color { color.opacity(0.5) }
  private var emptyColor: Color { color.opacity(0.3) }
  private let maxDuration: TimeInterval = 240
  private let maxVolume: Double = 1

  var body: some View {
    NavigationView {
      GeometryReader { geometry in
        contentLayer(size: geometry.size, safeArea: geometry.safeAreaInsets)
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
  }

  private func contentLayer(size: CGSize, safeArea: EdgeInsets) -> some View {
    ZStack {
      RoundedRectangle(cornerRadius: animateContent ? deviceCornerRadius : 0, style: .continuous)
        .fill(.bg)
        .overlay(content: {
          RoundedRectangle(cornerRadius: animateContent ? deviceCornerRadius : 0, style: .continuous)
            .fill(.bg)
            .opacity(animateContent ? 1 : 0)
        })
        .overlay(alignment: .top) {
          MusicInfo(expandPlayer: $viewModel.expandPlayer, animation: animation, currentTitle: viewModel.currentTitle ?? "Not Playing", currentArtist: viewModel.currentArtist ?? "", currentThumbnailURL: viewModel.currentThumbnailURL ?? "musicnote")
            .allowsHitTesting(false)
            .opacity(animateContent ? 0 : 1)
        }
        .matchedGeometryEffect(id: "Background", in: animation)

      VStack(spacing: 15) {
        songorvideoTab

        albumArtwork
          .matchedGeometryEffect(id: "Album Cover", in: animation, isSource: false)
          .offset(x: isPlaying ? 0 : 47, y: isPlaying ? 0 : 47)
          .frame(width: 343, height: 343)
          .padding(.top, 5)
          .padding(.vertical, size.height < 700 ? 10 : 15)

        playerButtons(size: size)
          .offset(y: animateContent ? 0 : size.height)
      }
      .padding(.top, safeArea.top + (viewModel.expandPlayer ? 10 : 0))
      .padding(.bottom, safeArea.bottom == 0 ? 10 : safeArea.bottom)
      .padding(.horizontal, 25)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .clipped()
    }
  }
  
  private var songorvideoTab: some View {
    VStack(spacing: 15) {
      SongOrVideo(tabs: songorvideo.allCases, activeTab: $activeTab, height: 35, font: .body, activeTint: .primary, inActiveTint: .gray) { size in
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
        ZStack {
          // Use AsyncImage to load and display the thumbnail image
          APIPlayer(videoID: viewModel.currentVideoID ?? videoID)
          albumArt(isPlaying: isPlaying, animateContent: animateContent, currentThumbnailURL: viewModel.currentThumbnailURL ?? "musicnote")
        }
        .frame(width: isPlaying ? 343 : 250, height: isPlaying ? 343 : 250)
        .clipShape(RoundedRectangle(cornerRadius: animateContent ? 15 : 5, style: .continuous))
        .edgesIgnoringSafeArea(.all)
      } else if activeTab == .video {
        GeometryReader { _ in
          APIPlayer(videoID: viewModel.currentVideoID ?? videoID)
            .edgesIgnoringSafeArea(.all)
            .frame(width: isPlaying ? 343 : 250, height: isPlaying ? 343 : 250)
            .clipShape(RoundedRectangle(cornerRadius: animateContent ? 15 : 5, style: .continuous))
        }
      }
    }
  }

  func albumArt(isPlaying: Bool, animateContent: Bool, currentThumbnailURL: String) -> some View {
    if let url = URL(string: currentThumbnailURL) {
      return AnyView(
        AsyncImage(url: url) { phase in
          switch phase {
          case .success(let image):
            image.resizable()
              .scaledToFit()
              .frame(width: isPlaying ? 343 : 250, height: isPlaying ? 343 : 250)
              .clipShape(RoundedRectangle(cornerRadius: animateContent ? 15 : 5, style: .continuous))
          case .failure, .empty:
            Image("musicnote")
              .resizable()
              .scaledToFit()
              .frame(width: isPlaying ? 343 : 250, height: isPlaying ? 343 : 250)
              .clipShape(RoundedRectangle(cornerRadius: animateContent ? 15 : 5, style: .continuous))
          @unknown default:
            EmptyView()
          }
        }
      )
    } else {
      return AnyView(
        Image("musicnote")
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: isPlaying ? 343 : 250, height: isPlaying ? 343 : 250)
          .clipShape(RoundedRectangle(cornerRadius: animateContent ? 15 : 5, style: .continuous))
      )
    }
  }

  private func playerButtons(size: CGSize) -> some View {
    VStack(spacing: size.height * 0.04) {
      GeometryReader { proxy in
        let spacing = proxy.size.height * 0.04

        VStack(spacing: spacing) {
          VStack(spacing: spacing) {
            HStack(alignment: .center, spacing: 15) {
              VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.currentTitle ?? "Not Playing")
                  .font(.title3)
                  .fontWeight(.semibold)

                Text(viewModel.currentArtist ?? "")
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
                  .font(.system(size: 21))
                  .foregroundColor(.white)
                  .padding(12)
                  .padding(.bottom, 8)
                  .padding(.leading, 12)
              }
            }

            //Song Duration Slider
            MusicProgressSlider(value: $playerDuration, inRange: TimeInterval.zero...maxDuration, activeFillColor: color, fillColor: normalFillColor, emptyColor: emptyColor, height: 32) { started in

            }
            .padding(.top, spacing)
          }
          .frame(height: proxy.size.height / 2.5, alignment: .top)

          //MARK: Playback Controls
          HStack(spacing: proxy.size.width * 0.18) {
            BackwardButton()

            Button {
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

            HStack(alignment: .top, spacing: proxy.size.width * 0.18) {
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
              .padding(.top, 3)
              //              NavigationLink(
              //                destination: Lyrics(animation: animation), label: {
              //                  Image(systemName: "quote.bubble")
              //                    .font(.title2)
              //                })
              //              .padding(.top, 3)
              //
              //              AirPlayButton()
              //                .frame(width: 50, height: 50)
              //                .padding(.top, -13)
              //                .padding(.horizontal, 25)
              //
              //              NavigationLink(
              //                destination: UpNext(animation: animation), label: {
              //                  Image(systemName: "list.bullet")
              //                    .font(.title2)
              //                })
              //              .padding(.top, 3)
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
            viewModel.expandPlayer = false
            animateContent = false
          } else {
            offsetY = .zero
          }
        }
      })
  }
}

#Preview {
  Main(videoID: "")
    .preferredColorScheme(.dark)
}
