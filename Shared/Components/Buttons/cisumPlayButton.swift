//
//  cisumPlayButton.swift
//  cisum
//
//  Created by Aarav Gupta (github.com/atpugvaraa) on 05/05/25.
//

import SwiftUI

struct cisumPlayButton: View {
    @Environment(PlayerViewModel.self) private var playerViewModel
    @State private var transparency: Double = 0.0
    
    #if DEBUG
    @ObserveInjection var forceRedraw
    #endif

    var body: some View {
        Button {
            playerViewModel.togglePlayPause()
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
                Image(systemName: playerViewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 50))
            }
        }
        .padding(.horizontal, -25)
        .enableInjection()
    }
}
