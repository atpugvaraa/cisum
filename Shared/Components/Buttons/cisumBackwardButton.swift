//
//  cisumBackwardButton.swift
//  cisum
//
//  Created by Aarav Gupta (github.com/atpugvaraa) on 05/05/25.
//


import SwiftUI

struct cisumBackwardButton: View {
    @Environment(PlayerViewModel.self) private var playerViewModel
    @State private var transparency: Double = 0.0
    
    var body: some View {
        Button {
            playerViewModel.skipToPrevious()
            transparency = 0.6
            withAnimation(.easeOut(duration: 0.2)) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    transparency = 0.0
                }
            }
        } label: {
            ZStack {
                Circle()
                    .frame(width: 50, height: 50)
                    .opacity(transparency)
                Image(systemName: "backward.fill")
                    .font(.title)
//                    .animation(.interpolatingSpring(stiffness: 170, damping: 15), value: player.isBackwarded)
            }
        }
        .disabled(!playerViewModel.canSkipBackward)
        .opacity(playerViewModel.canSkipBackward ? 1 : 0.5)
    }
}
