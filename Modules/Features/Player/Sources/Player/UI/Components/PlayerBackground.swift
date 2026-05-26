//
//  PlayerBackground.swift
//  cisum
//
//  Created by Aarav Gupta on 28/03/26.
//

#if os(iOS)
import Kingfisher
import SwiftUI
import DesignSystem
import Utilities
import Services

struct PlayerBackground: View {
    @Environment(PlaybackServices.self) private var playbackServices
    private var playerViewModel: any PlayerViewModelInterface { playbackServices.playerViewModel }

    let isPlayerExpanded: Bool
    let isFullExpanded: Bool
    var canBeExpanded: Bool = true

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.bar)

            if canBeExpanded {
                Rectangle()
                    .fill(.ultraThickMaterial)
                    .overlay {
                        ZStack {
                            playerViewModel.currentAccentColor
                                .scaleEffect(1.1)
                                .blur(radius: 10)

                            DesignSystem.Vinyl(
                                isPlaying: playerViewModel.isPlaying,
                                accentColor: playerViewModel.currentAccentColor
                            ) {
                                KFImage(playerViewModel.currentImageURL)
                                    .downsampling(size: CGSize(width: 1400, height: 1400))
                                    .resizable()
                                    .scaledToFill()
                            } previous: {
                                Image.vinylNotPlaying
                                    .resizable()
                            } upnext: {
                                Image.vinylNotPlaying
                                    .resizable()
                            }

                            ZStack {
                                Color.white.opacity(0.1)
                                    .scaleEffect(1.8)
                                    .blur(radius: 100)

                                Color.black.opacity(0.35)
                            }
                            .compositingGroup()
                        }
                        .compositingGroup()
                    }
                    .opacity(isPlayerExpanded ? 1 : 0)
            }
        }
        .clipShape(.rect(cornerRadius: dynamicCornerRadius))
        .frame(height: isPlayerExpanded ? nil : Utilities.AppConstants.dynamicPlayerIslandHeight)

    }
}

extension PlayerBackground {
    fileprivate var dynamicCornerRadius: CGFloat {
        isPlayerExpanded ? expandPlayerCornerRadius : collapsedPlayerCornerRadius
    }

    fileprivate var expandPlayerCornerRadius: CGFloat {
        isFullExpanded ? 0 : UIScreen.deviceCornerRadius
    }

    fileprivate var collapsedPlayerCornerRadius: CGFloat {
        Utilities.AppConstants.dynamicPlayerIslandHeight / 2
    }
}
#endif
