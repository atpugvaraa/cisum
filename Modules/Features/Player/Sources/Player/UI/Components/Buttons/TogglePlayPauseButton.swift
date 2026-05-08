//
//  cisumPlayButton.swift
//  cisum
//
//  Created by Aarav Gupta (github.com/atpugvaraa) on 05/05/25.
//

import SwiftUI
import Services

struct TogglePlayPauseButton: View {
@Environment(PlaybackServices.self) private var playbackServices
    private var playerViewModel: any PlayerViewModelInterface { playbackServices.playerViewModel }
    
    @State private var transparency: Double = 0.0

    

    var body: some View {
        Button {
            playerViewModel.togglePlayPause()
            transparency = 0.6
            Task {
                try? await Task.sleep(for: .milliseconds(200))
                withAnimation(.easeOut(duration: 0.2)) {
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
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .sensoryFeedback(.selection, trigger: playerViewModel.isPlaying)
        .accessibilityLabel(playerViewModel.isPlaying ? "Pause" : "Play")
        .padding(.horizontal, -25)

    }
}
