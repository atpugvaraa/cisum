//
//  Music Info.swift
//  cisum
//
//  Created by Aarav Gupta on 19/03/24.
//

import SwiftUI
import SDWebImageSwiftUI

struct MusicInfo: View {
  @EnvironmentObject var viewModel: PlayerViewModel
  var title: String
  var artistName: String
  var thumbnailURL: String
  var animation: Namespace.ID
  @Binding var expandPlayer: Bool
  @State private var animateContent: Bool = false
  @State private var offsetY: CGFloat = 0
  @State private var isPlaying: Bool = false

  var body: some View {
    HStack(spacing: 0) {
      // MARK: Expand Animation
      ZStack {
        if !expandPlayer {
          // GeometryReader for dynamic sizing
          GeometryReader { _ in
            // Load and display the thumbnail image using SDWEBIMAGE
            WebImage(url: URL(string: viewModel.thumbnailURL ?? "musicnote")) { phase in
                switch phase {
                case .success(let image):
                  image.resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 42, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: expandPlayer ? 15 : 5, style: .continuous))
                case .failure:
                  Image("musicnote")
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 42, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: expandPlayer ? 15 : 5, style: .continuous))
                case .empty:
                  ProgressView() // Show a loading indicator if necessary
                }
              }
          }
          .matchedGeometryEffect(id: "Album Cover", in: animation)
        }
      }
      .padding(.leading, -7)
      .frame(width: 42, height: 42)

      // Display the current title
      Text(viewModel.title ?? "Not Playing")
        .fontWeight(.semibold)
        .lineLimit(1)
        .padding(.horizontal, 15)

      Spacer(minLength: 0)

      // AirPlay button
      AirPlayButton()
        .frame(width: 49, height: 49)

      // Play/Pause button
      PlayPauseButton()
        .padding(.leading, 10)
    }
    .foregroundColor(.primary)
    .padding(.horizontal)
    .frame(height: 58)
    .contentShape(Rectangle())
    .onTapGesture {
      withAnimation(.easeInOut(duration: 0.3)) {
        expandPlayer = true
      }
    }
    .gesture(
      DragGesture()
        .onChanged { value in
          let translationY = value.translation.height
          offsetY = min(translationY, 0) // Only allow upwards dragging
        }
        .onEnded { _ in
          withAnimation(.easeInOut(duration: 0.3)) {
            let screenHeight = UIScreen.main.bounds.height
            if offsetY < -screenHeight * 0.05 {
              expandPlayer = true
              animateContent = true
            } else {
              offsetY = 0
            }
          }
        }
    )
  }
}
