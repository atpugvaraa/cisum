//
//  Playlist.swift
//  cisum
//
//  Created by Aarav Gupta on 09/03/24.
//

import SwiftUI

struct Playlist: View {
  @State private var isPlaying = false
    @EnvironmentObject var viewModel: PlayerViewModel
  let accentColor = Color(red: 0.976, green: 0.176, blue: 0.282, opacity: 0.3)

  func getOffsetY(reader: GeometryProxy) -> CGFloat {
    let offsetY: CGFloat = -reader.frame(in: .named("scrollView")).minY
    if offsetY < 0 {
      return offsetY / 1.3
    }
    return offsetY
  }
    var body: some View {
        ScrollView(showsIndicators: false) {
            // Album Cover Art
            GeometryReader { reader in
              let offsetY = getOffsetY(reader: reader)
              let height: CGFloat = (reader.size.height - offsetY) + offsetY / 3
              let minHeight: CGFloat = 120
              let opacity = (height - minHeight) / (reader.size.height - minHeight)

                ZStack {
                  LinearGradient(gradient: Gradient(colors: [accentColor, Color.black.opacity(0.84)]), startPoint: .top, endPoint: .bottom)
                    .scaleEffect(7)
                  Image("Image")
                    .resizable()
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                    .frame(width: height, height: height)
                    .offset(y: offsetY)
                    .opacity(Double(opacity))
                    .shadow(color: Color.black.opacity(0.5), radius: 30)
                }
                .frame(width: reader.size.width)
            }
            .frame(height: 250)

          albumDetails
            .padding(.horizontal)
        }
        .coordinateSpace(name: "scrollView")
        .background(accentColor.ignoresSafeArea())
    }

  var albumDetails: some View {
    HStack {
      VStack{
        Text("Spring Skies")
          .font(.title)
          .bold()
      }
      .foregroundColor(.white)

      Spacer()

      Button {
        isPlaying.toggle()
      } label: {
        ZStack {
          Circle()
            .foregroundColor(accentColor.opacity(0.75))
          Image(systemName: "pause.fill")
              .font(.system(size: 25))
              .scaleEffect(isPlaying ? 1 : 0)
              .opacity(isPlaying ? 1 : 0)
              .animation(.interpolatingSpring(stiffness: 170, damping: 15), value: isPlaying)
          Image(systemName: "play.fill")
              .font(.system(size: 25))
              .scaleEffect(isPlaying ? 0 : 1)
              .opacity(isPlaying ? 0 : 1)
              .animation(.interpolatingSpring(stiffness: 170, damping: 15), value: isPlaying)
        }
        .frame(width: 60, height: 60)
      }

    }
  }
}

#Preview {
  Playlist()
}
