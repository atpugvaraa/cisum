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
  var body: some View {
    HStack(spacing: 0) {
      //MARK: Expand Animation
      ZStack {
        if !expandPlayer {
          GeometryReader {
            let size = $0.size

            Image("Image")
              .resizable()
              .aspectRatio(contentMode: .fill)
              .frame(width: size.width, height: size.height)
              .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
          }
          .matchedGeometryEffect(id: "Album Cover", in: animation)
        }
      }
      .frame(width: 45, height: 45)

      Text("Song Name")
        .fontWeight(.semibold)
        .lineLimit(1)
        .padding(.horizontal, 15)

      Spacer(minLength: 0)

      Button {

      } label: {
        Image(systemName: "airplayaudio")
          .font(.title2)
      }

      Button {

      } label: {
        Image(systemName: "play.fill")
          .font(.title2)
      }
      .padding(.leading, 25)
    }
    .foregroundColor(.primary)
    .padding(.horizontal)
    .padding(.bottom, 5)
    .frame(height: 70)
    .contentShape(Rectangle())
    .onTapGesture {
      //Expanding Player
      withAnimation(.easeInOut(duration: 0.3)) {
        expandPlayer = true
      }
    }
  }
}
