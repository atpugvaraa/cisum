//
//  PlayerSurfaces.swift
//  cisum
//
//  Created by Codex on 28/03/26.
//

#if os(iOS)
import Kingfisher
import SwiftUI

struct PlayerAmbientBackground: View {
    @Environment(PlayerViewModel.self) private var playerViewModel

    var body: some View {
        ZStack {
            playerViewModel.currentAccentColor
                .scaleEffect(1.1)
                .blur(radius: 10)

            Vinyl {
                KFImage(playerViewModel.currentImageURL)
                    .resizable()
                    .scaledToFill()
            } previous: {
                Image(.notPlaying)
                    .resizable()
            } upnext: {
                Image(.notPlaying)
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
}

struct PlayerExpandedBackground: View {
    let isExpanded: Bool
    var includesCollapsedBarLayer: Bool = true

    var body: some View {
        ZStack {
            if includesCollapsedBarLayer {
                Rectangle()
                    .fill(.bar)
            }

            Rectangle()
                .fill(.ultraThickMaterial)
                .overlay {
                    PlayerAmbientBackground()
                }
                .opacity(isExpanded ? 1 : 0)
        }
    }
}

@available(iOS 26.0, *)
struct PlayerGlassBar<Content: View>: View {
    let namespace: Namespace.ID
    var cornerRadius: CGFloat = 50
    var height: CGFloat = 48
    @ViewBuilder var content: Content

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(.clear)
            .glassEffect(.identity)
            .matchedGeometryEffect(id: "GLASS", in: namespace)
            .frame(height: height)
            .overlay {
                content
            }
    }
}
#endif
