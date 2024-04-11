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
    GeometryReader {
      let size = $0.size
      let safeArea = $0.safeAreaInsets

      ZStack {
        RoundedRectangle(cornerRadius: animateContent ? deviceCornerRadius : 0, style: .continuous)
          .fill(.ultraThickMaterial)
          .overlay(content: {
            RoundedRectangle(cornerRadius: animateContent ? deviceCornerRadius : 0, style: .continuous)
              .fill(.ultraThickMaterial)
              .opacity(animateContent ? 1 : 0)
          })
          .overlay(alignment: .top) {
            MusicInfo(expandPlayer: $viewModel.expandPlayer, animation: animation, currentTitle: viewModel.currentTitle ?? "Not Playing", currentArtist: viewModel.currentArtist ?? "", currentThumbnailURL: viewModel.currentThumbnailURL ?? "musicnote")
              .allowsHitTesting(false)
              .opacity(animateContent ? 0 : 1)
          }
          .matchedGeometryEffect(id: "Background", in: animation)

        VStack(spacing: 15) {
          //Song/Video
          VStack(spacing: 15) {
            SongOrVideo(tabs: songorvideo.allCases, activeTab: $activeTab, height: 35, font: .body, activeTint: .primary, inActiveTint: .gray.opacity(0.5)) { size in
              RoundedRectangle(cornerRadius: 30)
                .fill(accentColor)
                .frame(height: size.height)
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .background {
              RoundedRectangle(cornerRadius: 30)
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            }
            .padding(.horizontal, 15)

            Spacer(minLength: 0)
          }
          .frame(width: 210, height: 35)
          .padding(.vertical, 15)
          .toolbarBackground(.hidden, for: .navigationBar)
          .opacity(animateContent ? 1 : 0)
          //Fixing Slide Animation
          .offset(y: animateContent ? 0 : size.height)

          //MARK: Async Artwork
          GeometryReader {
            let size = $0.size

            if activeTab == .song {
              ZStack {
                APIPlayer(videoID: viewModel.currentVideoID ?? videoID)
                  .frame(width: isPlaying ? size.width : 250, height: isPlaying ? size.height : 250)
                  .clipShape(RoundedRectangle(cornerRadius: animateContent ? 15 : 5, style: .continuous))
                if let url = URL(string: currentThumbnailURL) {
                  return AnyView(
                    AsyncImage(url: url) { phase in
                      switch phase {
                      case .success(let image):
                        image.resizable()
                          .scaledToFit()
                          .frame(width: isPlaying ? size.width : 250, height: isPlaying ? size.height : 250)
                          .clipShape(RoundedRectangle(cornerRadius: animateContent ? 15 : 5, style: .continuous))
                      case .failure, .empty:
                        Image("musicnote")
                          .resizable()
                          .scaledToFit()
                          .frame(width: isPlaying ? size.width : 250, height: isPlaying ? size.height : 250)
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
                      .frame(width: isPlaying ? size.width : 250, height: isPlaying ? size.height : 250)
                      .clipShape(RoundedRectangle(cornerRadius: animateContent ? 15 : 5, style: .continuous))
                  )
                }
              }
            } else if activeTab == .video {
              GeometryReader {
                let size = $0.size
                APIPlayer(videoID: viewModel.currentVideoID ?? videoID)
              }
            }
          }
          .matchedGeometryEffect(id: "Album Cover", in: animation)
          //Square Artwork Image
          .offset(x: isPlaying ? 0 : 47, y: isPlaying ? 0 : 47)
          .frame(width: 343, height: 343)
          .padding(.top, -25)
          .padding(.vertical, size.height < 700 ? 10 : 15)

          //Player Sliders
          PlayerButtons(size: size)
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
      .gesture(
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
      )
      .ignoresSafeArea(.container, edges: .all)
    }
    .onAppear {
      withAnimation(.easeInOut(duration: 0.35)) {
        animateContent = true
      }
    }
  }

  @ViewBuilder
  func PlayerButtons(size: CGSize) -> some View {
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
                .font(.title2)
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
        .frame(height: size.height / 2.5, alignment: .top)

        //MARK: Playback Controls
        HStack(spacing: size.width * 0.18) {
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

          HStack(alignment: .top, spacing: size.width * 0.18) {
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
        .frame(height: size.height / 2.5, alignment: .bottom)
      }
    }
  }
}

#Preview {
  Main(videoID: "")
    .preferredColorScheme(.dark)
}
