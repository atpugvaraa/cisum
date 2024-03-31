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
    
    var body: some View {
        HStack(spacing: 0) {
            //MARK: Expand Animation
            ZStack {
                if !expandPlayer {
                    GeometryReader { geometry in
                        let size = geometry.size // Capture size here
                        
                        Image("Image")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: expandPlayer ? 15 : 5, style: .continuous))
                    }
                    .matchedGeometryEffect(id: "Album Cover", in: animation)
                }
            }
            .padding(.leading, -5)
            .frame(width: 40, height: 40)
            
            Text("Song Name")
                .fontWeight(.semibold)
                .lineLimit(1)
                .padding(.horizontal, 10)
            
            Spacer(minLength: 0)
            
            AirPlayButton()
                .frame(width: 50, height: 50)
            
            PlayPauseButton()
                .padding(.leading, 5)
        }
        .foregroundColor(.primary)
        .padding(.horizontal)
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged({ value in
                    let translationY = value.translation.height
                    offsetY = (translationY < 0 ? translationY : 0) // Change comparison to less than 0
                })
                .onEnded({ value in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        let size = UIScreen.main.bounds.size // Retrieve size here
                        if offsetY < -size.height * 0.05 { // Adjusted threshold here
                            expandPlayer = true // Expand player when dragged upwards
                            animateContent = true
                        } else {
                            offsetY = .zero
                        }
                    }
                })
        )
    }
}

#Preview {
  Main()
    .preferredColorScheme(.dark)
}
