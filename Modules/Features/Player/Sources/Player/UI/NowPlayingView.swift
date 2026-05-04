//
//  NowPlayingView.swift
//  cisum
//
//  Created by Aarav Gupta on 05/12/25.
//

#if os(iOS)
    import SwiftUI
    import Services
    import Utilities

    public struct NowPlayingView: View {
        @Environment(Services.ServicesContainer.self) private var container
        private var playerViewModel: any PlayerViewModelInterface { container.playback.playerViewModel }

        public var isPlayerExpanded: Bool
        public var size: CGSize
        public var namespace: Namespace.ID

        public init(isPlayerExpanded: Bool, size: CGSize, namespace: Namespace.ID) {
            self.isPlayerExpanded = isPlayerExpanded
            self.size = size
            self.namespace = namespace
        }

        public var body: some View {
            VStack(spacing: 12) {
                header

                NowPlayingArtwork(size: size, artworkURL: playerViewModel.currentImageURL)

                NowPlayingSongInfo()

                GeometryReader { proxy in
                    NowPlayingControls(size: proxy.size, safeArea: proxy.safeAreaInsets)
                }
            }
            .padding(.horizontal, 15)
            .padding(.top, AppConstants.safeAreaInsets.top)
            .padding(.bottom, AppConstants.safeAreaInsets.bottom)

        }
    }

    extension NowPlayingView {
        fileprivate var header: some View {
            Capsule()
                .fill(.white.secondary)
                .blendMode(.overlay)
                .opacity(isPlayerExpanded ? 1 : 0)
                .frame(width: 40, height: 5)
                .offset(y: 10)
        }
    }
#endif
