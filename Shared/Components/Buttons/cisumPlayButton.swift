//
//  cisumPlayButton.swift
//  cisum
//
//  Created by Aarav Gupta (github.com/atpugvaraa) on 05/05/25.
//

#warning("Please fix the player controls when Player VM is done")
import SwiftUI

struct cisumPlayButton: View {
    @State private var transparency: Double = 0.0
    
    var body: some View {
        Button {
            // Action to toggle play
            transparency = 0.6
            withAnimation(.easeOut(duration: 0.2)) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    transparency = 0.0
                }
            }
        } label: {
            ZStack {
                Circle()
                    .frame(width: 75, height: 75)
                    .opacity(transparency)
                Image(systemName: "pause.fill")
                    .font(.system(size: 50))
//                    .scaleEffect(player.isPlaying ? 1 : 0)
//                    .opacity(player.isPlaying ? 1 : 0)
//                    .animation(.interpolatingSpring(stiffness: 170, damping: 15), value: player.isPlaying)
//                Image(systemName: "play.fill")
//                    .font(.system(size: 50))
//                    .scaleEffect(player.isPlaying ? 0 : 1)
//                    .opacity(player.isPlaying ? 0 : 1)
//                    .animation(.interpolatingSpring(stiffness: 170, damping: 15), value: player.isPlaying)
            }
        }
        .padding(.horizontal, -25)
    }
}
