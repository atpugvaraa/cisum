//
//  DynamicPlayerIsland.swift
//  cisum
//
//  Created by Aarav Gupta on 13/03/26.
//

import Kingfisher
import SwiftUI
import Services
import DesignSystem

#if os(macOS)
public struct DynamicPlayerIsland: View {
@Environment(PlaybackServices.self) private var playbackServices
    private var playerViewModel: any PlayerViewModelInterface { playbackServices.playerViewModel }
    @Environment(\.isDynamicPlayerExpanded) private var isDynamicPlayerExpanded
    
    public init() {}

    @State private var isHovering = false
    @State private var isLyricsExpanded = false
    @Namespace private var namespace

    var isMiniPlayerExpanded: Bool {
        get { isDynamicPlayerExpanded.wrappedValue }
        nonmutating set { isDynamicPlayerExpanded.wrappedValue = isLyricsExpanded }
    }

    

    var body: some View {
        surface
            .aspectRatio(isLyricsExpanded ? (1 / 2.5) : isHovering ? 5 / 3 : 5, contentMode: .fit)
            .frame(maxHeight: panelHeight)
            .overlay {
                islandContent
            }
            .onHover { hovering in
                withAnimation(.playerExpandAnimation) {
                    isHovering = hovering
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .animation(.playerExpandAnimation, value: presentationState)
            .environment(\.isDynamicPlayerExpanded, $isLyricsExpanded)

    }
}

extension DynamicPlayerIsland {
    fileprivate enum PresentationState {
        case compact
        case controls
        case lyrics
    }

    fileprivate enum Layout {
        static let compactWidth: CGFloat = 260
        static let compactHeight: CGFloat = 60
        static let expandedWidth: CGFloat = 300
        static let expandedHeight: CGFloat = 180
        static let lyricsWidth: CGFloat = 425
    }

    fileprivate var presentationState: PresentationState {
        if isLyricsExpanded {
            return .lyrics
        }

        return isHovering ? .controls : .compact
    }

    fileprivate var panelWidth: CGFloat {
        switch presentationState {
        case .compact:
            return Layout.compactWidth
        case .controls:
            return Layout.expandedWidth
        case .lyrics:
            return Layout.lyricsWidth
        }
    }

    fileprivate var panelHeight: CGFloat {
        switch presentationState {
        case .compact:
            return Layout.compactHeight
        case .controls:
            return Layout.expandedHeight
        case .lyrics:
            return .infinity
        }
    }

    @ViewBuilder
    fileprivate var surface: some View {
        if #available(macOS 26.0, *) {
            RoundedRectangle(cornerRadius: isHovering ? 21 : (isLyricsExpanded ? 21 : 50))
                .glassEffect(
                    .regular,
                    in: .rect(cornerRadius: isHovering ? 21 : (isLyricsExpanded ? 21 : 50)))
        } else {
            RoundedRectangle(
                cornerRadius: isHovering ? 21 : (isLyricsExpanded ? 21 : 50), style: .circular
            )
            .fill(.ultraThinMaterial)
        }
    }

    @ViewBuilder
    fileprivate var islandContent: some View {
        switch presentationState {
        case .compact:
            compactContent
        case .controls:
            controlsContent
        case .lyrics:
            lyricsContent
        }
    }

    fileprivate var compactContent: some View {
        HStack(spacing: 10) {
            artwork(size: 44, cornerRadius: 22)

            songInfo(
                titleFont: .system(size: 14, weight: .semibold),
                artistFont: .system(size: 12, weight: .semibold),
                titleLineLimit: 1,
                artistLineLimit: 1
            )

            Spacer(minLength: 6)

            Image(systemName: "waveform")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    fileprivate var controlsContent: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                artwork(size: 48, cornerRadius: 10)

                songInfo(
                    titleFont: .system(size: 15, weight: .semibold),
                    artistFont: .system(size: 14, weight: .semibold),
                    titleLineLimit: 1,
                    artistLineLimit: 1
                )
            }

            playbackProgress

            playbackControls
        }
        .padding(12)
    }

    fileprivate var lyricsContent: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                artwork(size: 48, cornerRadius: 10)

                songInfo(
                    titleFont: .system(size: 15, weight: .semibold),
                    artistFont: .system(size: 14, weight: .semibold),
                    titleLineLimit: 1,
                    artistLineLimit: 1
                )

                Spacer(minLength: 6)
            }

            lyricsLines

            playbackProgress

            playbackControls
        }
        .padding(12)
    }

    fileprivate func artwork(size: CGFloat, cornerRadius: CGFloat) -> some View {
        KFImage(playerViewModel.currentImageURL)
            .placeholder {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.white.opacity(0.2))
            }
            .downsampling(size: CGSize(width: size * 2, height: size * 2))
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.15), lineWidth: 1)
            }
            .matchedGeometryEffect(id: "Artwork", in: namespace)
    }

    fileprivate func songInfo(
        titleFont: Font,
        artistFont: Font,
        titleLineLimit: Int,
        artistLineLimit: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(nowPlayingTitle)
                .font(titleFont)
                .foregroundStyle(.white.opacity(0.97))
                .lineLimit(titleLineLimit)

            Text(nowPlayingArtist)
                .font(artistFont)
                .foregroundStyle(.white.opacity(0.76))
                .lineLimit(artistLineLimit)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .matchedGeometryEffect(id: "SongInfo", in: namespace)
    }

    fileprivate var playbackProgress: some View {
        MusicProgressScrubber(
            mediaID: playerViewModel.currentVideoId,
            currentTime: playerViewModel.currentTime,
            duration: playerViewModel.duration,
            onSeek: { newTime in
                playerViewModel.seek(to: newTime)
            }
        )
    }

    fileprivate var playbackControls: some View {
        HStack(spacing: 26) {
            lyricsToggle

            previous

            togglePlayPause

            next

            volumeButton
        }
        .foregroundStyle(.white.opacity(0.95))
    }

    fileprivate var lyricsLines: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 6) {
                if !playerViewModel.syncedLyricsLines.isEmpty {
                    ForEach(Array(playerViewModel.syncedLyricsLines.enumerated()), id: \.offset) {
                        index, line in
                        let isCurrentLyric = index == playerViewModel.currentSyncedLyricIndex

                        Text(line.text)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(isCurrentLyric ? 0.98 : 0.68))
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    ForEach(Array(displayLyrics.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.68))
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.bottom, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    fileprivate var nowPlayingTitle: String {
        let cleaned = playerViewModel.currentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Not Playing" : cleaned
    }

    fileprivate var nowPlayingArtist: String {
        let cleaned = playerViewModel.currentArtist.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Unknown Artist" : cleaned
    }

    fileprivate var displayLyrics: [String] {
        let syncedLines = playerViewModel.syncedLyricsLines
            .map(\.text)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !syncedLines.isEmpty {
            return syncedLines
        }

        if let plainLyricsText = playerViewModel.plainLyricsText {
            let plainLines =
                plainLyricsText
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if !plainLines.isEmpty {
                return plainLines
            }
        }

        switch playerViewModel.lyricsState {
        case .loading:
            return ["Loading lyrics..."]
        case .unavailable(let message):
            return [message]
        default:
            return ["Lyrics unavailable for this track."]
        }
    }

    fileprivate var lyricsToggle: some View {
        Button {
            withAnimation(.playerExpandAnimation) {
                isLyricsExpanded.toggle()
            }
        } label: {
            Image(systemName: isLyricsExpanded ? "quote.bubble.fill" : "quote.bubble")
                .font(.system(size: 20, weight: .semibold))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isLyricsExpanded ? "Hide lyrics" : "Show lyrics")
    }

    fileprivate var previous: some View {
        Button {
            playerViewModel.skipToPrevious()
        } label: {
            Image(systemName: "backward.fill")
                .font(.system(size: 23, weight: .semibold))
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
                .font(.system(size: 34, weight: .bold))
        }
        .buttonStyle(.plain)
        .disabled(playerViewModel.currentVideoId == nil)
        .opacity(playerViewModel.currentVideoId == nil ? 0.35 : 1)
        .accessibilityLabel(playerViewModel.isPlaying ? "Pause" : "Play")
    }

    fileprivate var next: some View {
        Button {
            playerViewModel.skipToNext()
        } label: {
            Image(systemName: "forward.fill")
                .font(.system(size: 23, weight: .semibold))
        }
        .buttonStyle(.plain)
        .disabled(!playerViewModel.canSkipForward)
        .opacity(playerViewModel.canSkipForward ? 1 : 0.35)
        .accessibilityLabel("Next")
    }

    fileprivate var volumeButton: some View {
        Button {
        } label: {
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 18, weight: .semibold))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Audio")
    }
}
#endif
