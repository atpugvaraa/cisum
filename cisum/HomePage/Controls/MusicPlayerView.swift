//
//  MusicPlayer.swift
//  cisum
//
//  Created by Aarav Gupta on 18/02/24.
//
import SwiftUI

struct MusicPlayer: View {
  @State var isMusicPlaying = false
  @State var isLiked = false
  @State private var isShowingQueueView = false
  @Binding var expandSheet: Bool
  var animation: Namespace.ID
  @State private var animateContent: Bool = false
  @State private var offsetY: CGFloat = 0
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
            MusicInfo(expandSheet: $expandSheet, animation: animation)
              .allowsHitTesting(false)
              .opacity(0)
          }
          .matchedGeometryEffect(id: "BGView", in: animation)

        VStack(spacing: 15) {

          Capsule()
            .fill(.gray)
            .frame(width: 40, height: 5)
            .opacity(animateContent ? 1 : 0)
            .offset(y: animateContent ? 0 : size.height)

          GeometryReader {
            let size = $0.size

            Image("Lady Gaga")
              .resizable()
              .aspectRatio(contentMode: .fill)
              .frame(width: size.width, height: size.height)
              .clipShape(RoundedRectangle(cornerRadius: animateContent ? 15 : 5, style: .continuous))
          }
          .matchedGeometryEffect(id: "Artwork", in: animation)
          .frame(height: size.width - 50)
          .padding(.vertical, size.height < 700 ? 10 : 30)

          Player(size)
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
          }).onEnded({ value in
            withAnimation(.easeInOut(duration: 0.3)) {
              if offsetY > size.height * 0.4 {
                expandSheet = false
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

  //MARK: Player
  @ViewBuilder
  func Player(_ mainSize: CGSize) -> some View {
    GeometryReader {
      let size = $0.size

      let spacing = size.height * 0.04

      VStack(spacing: spacing) {
        VStack(spacing: spacing) {
          HStack(alignment: .center, spacing: 15) {
            VStack(alignment: .leading, spacing: 4) {
              Text("Gugu Gaga")
                .font(.title3)
                .fontWeight(.semibold)

              Text("Lady Gaga")
                .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: {
              withAnimation(.spring()) {
                isLiked.toggle()
              }
            }, label: {
              Image(isLiked ? "Heart-filled" : "Heart")
                .font(.title2)
                .foregroundColor(.white)
                .padding(12)
            })

            Menu {
              Button(action: {
                // Action for Repeat button
              }) {
                Label("Repeat", systemImage: "repeat")
              }
              Button(action: {
                // Action for Shuffle button
              }) {
                Label("Shuffle", systemImage: "shuffle")
              }
              Button(action: {
                // Action for Add to Playlist button
              }) {
                Label("Add to Playlist", systemImage: "plus")
              }
            } label: {
              Label ("", systemImage: "ellipsis")
                .font(.title2)
                .foregroundColor(.white)
                .padding(12)
            }
            .padding(.bottom, 10)
          }
          .padding(.top, -25)

          // Replace the placeholder with actual implementation
          MusicProgressSlider(value: .constant(0.5), inRange: 0...69, activeFillColor: .white, fillColor: .white, emptyColor: .gray, height: 5) { editing in
            // Handle slider editing
          }
            .padding(.top)
        }
        .frame(height: size.height / 2.5, alignment: .top)

        HStack(spacing: size.width * 0.18) {
          Button {

          } label: {
            Image(systemName: "backward.fill")
              .font(size.height < 300 ? .title3 : .title)
          }

          Button(action: {
            withAnimation(.spring()) {
              isMusicPlaying.toggle()
            }
          }, label: { Image(systemName: isMusicPlaying ? "pause.fill" : "play.fill")
            .font(size.height < 300 ? .largeTitle : .system(size: 50))})

          Button {

          } label: {
            Image(systemName: "forward.fill")
              .font(size.height < 300 ? .title3 : .title)
          }
        }
        .padding(.top, -30)
        .foregroundColor(.white)
        .frame(maxHeight: .infinity)

        //Volume Controls
        VStack(spacing: spacing) {
          VolumeSlider(value: .constant(0.5), inRange: 0...100, activeFillColor: .white, fillColor: .white, emptyColor: .gray, height: 5) { editing in
            // Handle slider editing
          }
          .padding(.top, -75)

          HStack(alignment: .top, spacing: size.width * 0.18) {

            Button {

            } label: {
              Image(systemName: "quote.bubble")
                .font(.title2)
            }
            .padding(.top, -40)

            Button {

            } label: {
              Image(systemName: "airplayaudio")
                .font(.title2)
            }
            .padding(.top, -40)

            Button(action: { isShowingQueueView.toggle() }) {
              Image(systemName: "list.bullet")
                .font(.title2)
            }
            .sheet(isPresented: $isShowingQueueView) {
//              QueueView()
            }
            .padding(.top, -40)
          }
          .foregroundColor(.primary)
        }
        .frame(height: size.height / 2.5, alignment: .bottom)
      }
    }
  }
}

extension View {
  var deviceCornerRadius: CGFloat {
    let key = "_displayCornerRadius"
    if let screen = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.screen {
      if let corenerRadius = screen.value(forKey: key) as? CGFloat {
        return corenerRadius
      }

      return 0
    }

    return 0
  }
}

#Preview {
  Home()
    .preferredColorScheme(.dark)
}
