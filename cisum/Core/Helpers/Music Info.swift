//
//  Music Info.swift
//  cisum
//
//  Created by Aarav Gupta on 19/03/24.
//

import SwiftUI

struct MusicInfo: View {
  @Binding var expandPlayer: Bool
  var animation: Namespace.ID
  @State private var animateContent: Bool = false
  @State private var offsetY: CGFloat = 0
  @State private var isPlaying: Bool = false
  var currentTitle: String
  var currentArtist: String
  var currentThumbnailURL: String

  var body: some View {
    HStack(spacing: 0) {
      // MARK: Expand Animation
      ZStack {
        if !expandPlayer {
          // GeometryReader for dynamic sizing
          GeometryReader {
            let size = $0.size

            // Load and display the thumbnail image using AsyncImage
            if let url = URL(string: currentThumbnailURL), !expandPlayer {
              AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                  image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: expandPlayer ? 15 : 5, style: .continuous))
                    .matchedGeometryEffect(id: "Album Cover", in: animation)
                case .failure:
                  Image("musicnote")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: expandPlayer ? 15 : 5, style: .continuous))
                    .matchedGeometryEffect(id: "Album Cover", in: animation)
                case .empty:
                  ProgressView() // Show a loading indicator if necessary
                @unknown default:
                  EmptyView()
                }
              }
            }
          }
        }
      }
      .padding(.leading, -5)
      .frame(width: 40, height: 40)

      // Display the current title
      Text(currentTitle)
        .fontWeight(.semibold)
        .lineLimit(1)
        .padding(.horizontal, 10)

      Spacer(minLength: 0)

      // AirPlay button
      AirPlayButton()
        .frame(width: 50, height: 50)

      // Play/Pause button
      PlayPauseButton()
        .padding(.leading, 5)
    }
    .foregroundColor(.primary)
    .padding(.horizontal)
    .contentShape(Rectangle())
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
