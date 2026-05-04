//
//  cisumForwardButton.swift
//  cisum
//
//  Created by Aarav Gupta (github.com/atpugvaraa) on 05/05/25.
//

import SwiftUI
import Services

struct ForwardButton: View {
@Environment(ServicesContainer.self) private var container
    private var playerViewModel: any PlayerViewModelInterface { container.playback.playerViewModel }
    @State private var transparency: Double = 0.0

    var body: some View {
        Button {
            playerViewModel.skipToNext()
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
                Image(systemName: "forward.fill")
                    .font(.title)
            }
        }
        .sensoryFeedback(.impact, trigger: playerViewModel.currentVideoId)
        .accessibilityLabel("Skip Forward")
        .disabled(!playerViewModel.canSkipForward)
        .opacity(playerViewModel.canSkipForward ? 1 : 0.5)

    }
}
