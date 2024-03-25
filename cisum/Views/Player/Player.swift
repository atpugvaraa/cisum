//
//  Player.swift
//  cisum
//
//  Created by Aarav Gupta on 09/03/24.
//

import SwiftUI

struct Player: View {
  let AccentColor = Color(red : 0.9764705882352941, green: 0.17647058823529413, blue: 0.2823529411764706)
  @State private var activeTab: songorvideo = .song
  @Binding var expandPlayer: Bool
  var animation: Namespace.ID
  @State private var animateContent: Bool = false
  @State private var offsetY: CGFloat = 0
  @State private var liked: Bool = false
  @State private var isPlaying: Bool = false

  var body: some View {
    GeometryReader {
      let size = $0.size
      let safeArea = $0.safeAreaInsets

      ZStack {
        RoundedRectangle(cornerRadius: animateContent ? deviceCornerRadius : 0, style: .continuous)
          .fill(.ultraThinMaterial)
          .overlay(content: {
            RoundedRectangle(cornerRadius: animateContent ? deviceCornerRadius : 0, style: .continuous)
              .fill(.ultraThinMaterial)
              .opacity(animateContent ? 1 : 0)
          })
          .overlay(alignment: .top) {
            MusicInfo(expandPlayer: $expandPlayer, animation: animation)
              .allowsHitTesting(false)
              .opacity(animateContent ? 0 : 1)
          }
          .matchedGeometryEffect(id: "Background", in: animation)

        VStack(spacing: 15) {
          //Song/Video
          VStack(spacing: 15) {
            SongOrVideo(tabs: songorvideo.allCases, activeTab: $activeTab, height: 35, font: .body, activeTint: .primary, inActiveTint: .gray.opacity(0.5)) { size in
              RoundedRectangle(cornerRadius: 30)
                .fill(AccentColor)
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

          //Artwork
          GeometryReader {
            let size = $0.size

            Image("Image")
              .resizable()
              .aspectRatio(contentMode: .fill)
              .frame(width: size.width, height: size.height)
              .clipShape(RoundedRectangle(cornerRadius: animateContent ? 15 : 5, style: .continuous))
          }
          .matchedGeometryEffect(id: "Album Cover", in: animation)
          //Square Artwork Image
          .frame(height: size.width - 50)
          .padding(.top, -30)
          .padding(.vertical, size.height < 700 ? 10 : 15)

          //Player Controls
          PlayerControls(size: size)
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
  func PlayerControls(size: CGSize) -> some View {
    GeometryReader {
      let size = $0.size
      let spacing = size.height * 0.04

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
            }

            Button {
              // Button action
            } label: {
              Image(systemName: "ellipsis")
                .foregroundColor(.white)
                .padding(.horizontal, 12)
            }
          }

          //Song Duration Slider
          Capsule()
            .fill(.gray)
            .frame(height: 8)
            .padding(.top, spacing)

          //Song Duration Label
          HStack {
            Text("-:--")
              .font(.caption)

            Spacer(minLength: 0)

            Text("-:--")
              .font(.caption)
          }
          .foregroundColor(.gray)
        }
        .frame(height: size.height / 2.5, alignment: .top)

        //MARK: Playback Controls
        HStack(spacing: size.width * 0.18) {
          Button {

          } label: {
            Image(systemName: "backward.fill")
            //Dynamic Sizing
              .font(size.height < 300 ? .title3 : .title)
          }

          Button {
            isPlaying.toggle()
          } label: {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
            //Dynamic Sizing
              .font(size.height < 300 ? .largeTitle : .system(size: 50))
          }

          Button {

          } label: {
            Image(systemName: "forward.fill")
            //Dynamic Sizing
              .font(size.height < 300 ? .title3 : .title)
          }
        }
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

          HStack(alignment: .top, spacing: size.width * 0.18) {
            Button {

            } label: {
              Image(systemName: "quote.bubble")
                .font(.title2)
            }
            Button {

            } label: {
              Image(systemName: "airplayaudio")
                .font(.title2)
            }
            .padding(.horizontal, 25)
            Button {

            } label: {
              Image(systemName: "list.bullet")
                .font(.title2)
            }
          }
          .foregroundColor(.primary)
          .blendMode(.overlay)
          .padding(.top, spacing)
        }
        .padding(.bottom, 25)
        .frame(height: size.height / 2.5, alignment: .bottom)
      }
    }
  }
}

struct SongOrVideo<Indicator: View>: View {
  var tabs: [songorvideo]
  @Binding var activeTab: songorvideo
  var height: CGFloat = 35
  var displayAsText = true
  var font: Font = .title3
  var activeTint: Color
  var inActiveTint: Color
  //Indicator View
  @ViewBuilder var indicatorView: (CGSize) -> Indicator
  @State private var minX: CGFloat = .zero
  @State private var excessTabWidth: CGFloat = .zero
  var body: some View {
    GeometryReader {
      let size = $0.size
      let containerWidthForEachTab = size.width / CGFloat(tabs.count)

      HStack(spacing: 0) {
        ForEach(tabs, id: \.rawValue) { tab in
          Group {
            Text(tab.rawValue)
          }
          .font(font)
          .fontWeight(.semibold)
          .foregroundStyle(activeTab == tab ? activeTint : inActiveTint)
          .animation(.snappy, value: activeTab)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .contentShape(.rect)
          .onTapGesture {
            if let index = tabs.firstIndex(of: tab), let activeIndex = tabs.firstIndex(of: activeTab) {
              activeTab = tab

              withAnimation(Animation.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0)) {
                excessTabWidth = containerWidthForEachTab * CGFloat(index - activeIndex)
              }

              DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                withAnimation(Animation.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0)) {
                  minX = containerWidthForEachTab * CGFloat(index)
                  excessTabWidth = 0
                }
              }
            }
          }
          .background(alignment: .leading) {
            if tabs.first == tab {
              GeometryReader {
                let size = $0.size

                indicatorView(size)
                  .frame(width: size.width + (excessTabWidth < 0 ? -excessTabWidth : excessTabWidth), height: size.height)
                  .frame(width: size.width, alignment: excessTabWidth < 0 ? .trailing : .leading)
                  .offset(x: minX)
              }
            }
          }
        }
      }
    }
    .frame(height: height)
  }
}

enum songorvideo: String, CaseIterable {
  case song = "Song"
  case video = "Video"
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

//struct Player: View {
//  enum RepeatState {
//    case shuffle
//    case repeat_playlist
//    case repeat_one
//
//    // Toggle through the states including the shuffle option
//    mutating func toggle() {
//      switch self {
//      case .shuffle:
//        self = .repeat_playlist
//      case .repeat_playlist:
//        self = .repeat_one
//      case .repeat_one:
//        self = .shuffle
//      }
//    }
//
//
//    var systemImageName: String {
//      switch self {
//      case .shuffle:
//        return "shuffle"
//      case .repeat_playlist:
//        return "repeat"
//      case .repeat_one:
//        return "repeat.1"
//      }
//    }
//  }
//
//  @State var repeatState: RepeatState = .shuffle
//  @State private var isRepeating = false
//  @State var isMusicPlaying = false
//  @State var isLiked = false
//  @Binding var expand: Bool
//  var animation: Namespace.ID
//  @State private var animateContent: Bool = false
//  @State private var offsetY: CGFloat = 0
//  var body: some View {
//    GeometryReader {
//      let size = $0.size
//      let safeArea = $0.safeAreaInsets
//
//      ZStack {
//        RoundedRectangle(cornerRadius: animateContent ? deviceCornerRadius : 0, style: .continuous)
//          .fill(.ultraThinMaterial)
//          .overlay(content: {
//            RoundedRectangle(cornerRadius: animateContent ? deviceCornerRadius : 0, style: .continuous)
//              .fill(.ultraThinMaterial)
//              .opacity(animateContent ? 1 : 0)
//          })
//          .overlay(alignment: .top) {
//            MusicInfo(expand: $expand, animation: animation)
//              .allowsHitTesting(false)
//              .opacity(0)
//          }
//          .matchedGeometryEffect(id: "", in: animation)
//
//        VStack(spacing: 15) {
//
//          Capsule()
//            .fill(.gray)
//            .frame(width: 40, height: 5)
//            .opacity(animateContent ? 1 : 0)
//            .offset(y: animateContent ? 0 : size.height)
//
//          GeometryReader {
//            let size = $0.size
//
//            Image("Image")
//              .resizable()
//              .aspectRatio(contentMode: .fill)
//              .frame(width: size.width, height: size.height)
//              .clipShape(RoundedRectangle(cornerRadius: animateContent ? 15 : 5, style: .continuous))
//          }
//          .matchedGeometryEffect(id: "Album Cover", in: animation)
//          .frame(height: size.width - 50)
//          .padding(.vertical, size.height < 700 ? 10 : 30)
//
//          Player(size)
//            .offset(y: animateContent ? 0 : size.height)
//        }
//        .padding(.top, safeArea.top + (safeArea.bottom == 0 ? 10 : 0))
//        .padding(.bottom, safeArea.bottom == 0 ? 10 : safeArea.bottom)
//        .padding(.horizontal, 25)
//        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
//        .clipped()
//      }
//      .contentShape(Rectangle())
//      .offset(y: offsetY)
//      .gesture(
//        DragGesture()
//          .onChanged({ value in
//            let translationY = value.translation.height
//            offsetY = (translationY > 0 ? translationY : 0)
//          }).onEnded({ value in
//            withAnimation(.easeInOut(duration: 0.3)) {
//              if offsetY > size.height * 0.4 {
//                expand = false
//                animateContent = false
//              } else {
//                offsetY = .zero
//              }
//            }
//          })
//      )
//      .ignoresSafeArea(.container, edges: .all)
//    }
//    .onAppear {
//      withAnimation(.easeInOut(duration: 0.35)) {
//        animateContent = true
//      }
//    }
//  }
//
//  //MARK: Player
//  @ViewBuilder
//  func Player(_ mainSize: CGSize) -> some View {
//    GeometryReader {
//      let size = $0.size
//
//      let spacing = size.height * 0.04
//
//      VStack(spacing: spacing) {
//        VStack(spacing: spacing) {
//          HStack(alignment: .center, spacing: 15) {
//            VStack(alignment: .leading, spacing: 4) {
//              Text("Song Name")
//                .font(.title3)
//                .fontWeight(.semibold)
//
//              Text("Artist")
//                .foregroundColor(.gray)
//            }
//            .frame(maxWidth: .infinity, alignment: .leading)
//
//            Button(action: {
//              withAnimation(.spring()) {
//                isLiked.toggle()
//              }
//            }, label: {
//              Image(isLiked ? "Heart-filled" : "Heart")
//                .font(.title2)
//                .foregroundColor(.white)
//                .padding(12)
//            })
//
//            Menu {
//              Button(action: {
//                // Action for Add to Playlist button
//              }) {
//                Label("Add to Playlist", systemImage: "plus")
//              }
//
//              Button(action: {
//                // Action for Add to Playlist button
//              }) {
//                Label("Download", systemImage: "arrow.down.circle")
//              }
//
//              Button(action: {
//                // Action for Add to Playlist button
//              }) {
//                Label("Share", systemImage: "square.and.arrow.up")
//              }
//            } label: {
//              Label ("", systemImage: "ellipsis")
//                .font(.title2)
//                .foregroundColor(.white)
//                .padding(12)
//            }
//            .padding(.bottom, 10)
//          }
//          .padding(.top, -25)
//
//          Capsule()
//            .fill(.ultraThinMaterial)
//            .environment(\.colorScheme, .light)
//            .frame(height: 8)
//            .padding(.top, spacing)
//
//          HStack {
//            Text("-:--")
//              .font(.caption)
//              .foregroundColor(.gray)
//
//            Spacer(minLength: 0)
//
//            Text("-:--")
//              .font(.caption)
//              .foregroundColor(.gray)
//          }
//        }
//        .frame(height: size.height / 2.5, alignment: .top)
//
//        HStack(spacing: size.width * 0.18) {
//          Button {
//
//          } label: {
//            Image(systemName: "backward.fill")
//              .font(size.height < 300 ? .title3 : .title)
//          }
//
//          Button(action: {
//            withAnimation(.spring()) {
//              isMusicPlaying.toggle()
//            }
//          }, label: { Image(systemName: isMusicPlaying ? "pause.fill" : "play.fill")
//            .font(size.height < 300 ? .largeTitle : .system(size: 50))})
//
//          Button {
//
//          } label: {
//            Image(systemName: "forward.fill")
//              .font(size.height < 300 ? .title3 : .title)
//          }
//        }
//        .padding(.top, -30)
//        .foregroundColor(.white)
//        .frame(maxHeight: .infinity)
//
//        //Volume Controls
//        VStack(spacing: spacing) {
//          Image(systemName: "speaker.fill")
//            .foregroundColor(.gray)
//
//          Capsule()
//            .fill(.ultraThinMaterial)
//            .environment(\.colorScheme, .light)
//            .frame(height: 8)
//            .padding(.top, spacing)
//
//          Image(systemName: "speaker.wave.3.fill")
//            .foregroundColor(.gray)
//
//          HStack(alignment: .top, spacing: size.width * 0.18) {
//
//            Button {
//
//            } label: {
//              Image(systemName: "quote.bubble")
//                .font(.title2)
//            }
//            .padding(.top, -40)
//            .padding(.trailing, 25)
//
//            Button(action: {
//              repeatState.toggle()
//            }) {
//              Image(systemName: repeatState.systemImageName)
//                .font(.title2)
//            }
//            .padding(.top, -40)
//            .foregroundColor(.primary)
//
//            Button {
//
//            } label: {
//              Image(systemName: "list.bullet")
//                .font(.title2)
//            }
//            .padding(.top, -40)
//            .padding(.leading, 25)
//          }
//          .foregroundColor(.primary)
//          .blendMode(.overlay)
//          .padding(.top, spacing)
//        }
//        .frame(height: size.height / 2.5, alignment: .bottom)
//      }
//    }
//  }
//}
//

#Preview {
  Main()
    .preferredColorScheme(.dark)
}
