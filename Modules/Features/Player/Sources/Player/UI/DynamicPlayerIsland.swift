//
//  DynamicPlayerIsland.swift
//  cisum
//
//  Created by Aarav Gupta on 13/03/26.
//

import Kingfisher
import SwiftUI
import Services
import Utilities

#if os(iOS)
public struct DynamicPlayerIsland: View {
@Environment(ServicesContainer.self) private var container
    private var playerViewModel: any PlayerViewModelInterface { container.playback.playerViewModel }

    @Binding var isPlayerExpanded: Bool
    var namespace: Namespace.ID

    public init(isPlayerExpanded: Binding<Bool>, namespace: Namespace.ID) {
        self._isPlayerExpanded = isPlayerExpanded
        self.namespace = namespace
    }

    

    public var body: some View {
        nowPlaying
            .frame(height: Utilities.AppConstants.dynamicPlayerIslandHeight)
            .contentShape(.rect)
            .transformEffect(.identity)
            .onTapGesture {
                guard !isPlayerExpanded else { return }
                withAnimation(.playerExpandAnimation) {
                    isPlayerExpanded = true
                }
            }
            .simultaneousGesture(
                DragGesture()
                    //                    .onChanged { value in
                    //
                    //                    }
                    .onEnded { value in
                        let translation = value.translation
                        let width = translation.width
                        let height = translation.height

                        let threshold: CGFloat = 50

                        if abs(width) < threshold && abs(height) < threshold {
                            return  // ignore tiny gestures
                        }

                        if abs(width) > abs(height) * 1.2 {
                            // horizontal swipe
                            if width > threshold {
                                // right swipe
                                playerViewModel.skipToNext()
                            } else if width < -threshold {
                                // left swipe
                                playerViewModel.skipToPrevious()
                            }
                        } else {
                            // vertical swipe
                            if height < -threshold {
                                // swiped up
                                guard !isPlayerExpanded else { return }
                                withAnimation(.playerExpandAnimation) {
                                    isPlayerExpanded = true
                                }
                            }
                        }
                    }
            )

    }
}

extension DynamicPlayerIsland {
    @ViewBuilder
    fileprivate var artwork: some View {
        ZStack {
            if !isPlayerExpanded {
                KFImage(playerViewModel.currentImageURL)
                    .downsampling(size: CGSize(width: 80, height: 80))
                    .resizable()
                    .frame(width: 38, height: 38)
                    .aspectRatio(contentMode: .fit)
                    .clipShape(.circle)
            }
        }
    }

    fileprivate var nowPlaying: some View {
        HStack(spacing: 12) {
            artwork

            Text(playerViewModel.currentTitle)
                .fontWeight(.semibold)

            Spacer()

            HStack(spacing: 14) {
                previous

                togglePlayPause

                next
            }
            .font(.title3)
            .fontWeight(.bold)
        }
        .padding(.leading, 4)
        .padding(.trailing, 10)
    }

    fileprivate var previous: some View {
        Button {
            playerViewModel.skipToPrevious()
        } label: {
            Image(systemName: "backward.fill")
        }
        .buttonStyle(.plain)
        .disabled(!playerViewModel.canSkipBackward)
        .opacity(playerViewModel.canSkipBackward ? 1 : 0.35)
        .accessibilityLabel("Previous")
    }

    fileprivate var togglePlayPause: some View {
        Button {
            playerViewModel.togglePlayPause()
        } label: {
            Image(systemName: playerViewModel.isPlaying ? "pause.fill" : "play.fill")
        }
        .buttonStyle(.plain)
        .disabled(playerViewModel.currentVideoId == nil)
        .accessibilityLabel(playerViewModel.isPlaying ? "Pause" : "Play")
    }

    fileprivate var next: some View {
        Button {
            playerViewModel.skipToNext()
        } label: {
            Image(systemName: "forward.fill")
        }
        .buttonStyle(.plain)
        .disabled(!playerViewModel.canSkipForward)
        .opacity(playerViewModel.canSkipForward ? 1 : 0.35)
        .accessibilityLabel("Next")
    }
}
#endif
