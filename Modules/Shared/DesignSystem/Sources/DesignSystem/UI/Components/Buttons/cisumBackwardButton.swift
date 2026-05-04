//
//  cisumBackwardButton.swift
//  cisum
//
//  Created by Aarav Gupta (github.com/atpugvaraa) on 05/05/25.
//

import SwiftUI
import Services

struct PreviousButton: View {
    @Environment(ServicesContainer.self) private var container
    private var playerViewModel: any PlayerViewModelInterface { container.playback.playerViewModel }
    @State private var transparency: Double = 0.0

    var body: some View {
        Button {
            playerViewModel.skipToPrevious()
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
                    .frame(width: 50, height: 50)
                    .opacity(transparency)
                Image(systemName: "backward.fill")
                    .font(.title)
            }
        }
        .sensoryFeedback(.impact, trigger: playerViewModel.currentVideoId)
        .accessibilityLabel("Skip Backward")
        .disabled(!playerViewModel.canSkipBackward)
        .opacity(playerViewModel.canSkipBackward ? 1 : 0.5)

    }
}
