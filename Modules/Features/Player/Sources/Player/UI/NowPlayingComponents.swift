//
//  NowPlayingComponents.swift
//  cisum
//
//  Created by Aarav Gupta on 26/04/26.
//

import DesignSystem
import Kingfisher
import Services
import SwiftUI
import YouTubeSDK

// MARK: - Artwork Section

struct NowPlayingArtwork: View {
    let size: CGSize
    let artworkURL: URL?
    @Environment(PlaybackServices.self) private var playbackServices
    private var playerViewModel: any PlayerViewModelInterface { playbackServices.playerViewModel }

    var body: some View {
        GeometryReader { geometry in
            if playerViewModel.isLyricsVisible {
                LyricsView()
                    .frame(width: geometry.size.width, height: geometry.size.width)
            } else {
                Color.clear
                    .frame(width: geometry.size.width, height: geometry.size.width)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 15)
        .animation(
            .spring(response: 0.6, dampingFraction: 0.8), value: playerViewModel.isLyricsVisible
        )

    }
}

// MARK: - Song Info Section

struct NowPlayingSongInfo: View {
    @Environment(PlaybackServices.self) private var playbackServices
    private var playerViewModel: any PlayerViewModelInterface { playbackServices.playerViewModel }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(playerViewModel.currentTitle)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)

                    if playerViewModel.isExplicit {
                        Text("E")
                            .font(.caption2.bold())
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(4)
                            .background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
                    }
                }

                Text(playerViewModel.currentArtist)
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                Button {
                    // Favorite action
                } label: {
                    Image(systemName: "star")
                }
                .sensoryFeedback(.impact, trigger: playerViewModel.currentVideoId)

                Menu {
                    Button {
                        Task {
                            await playerViewModel.checkForHiResVersion()
                        }
                    } label: {
                        Label(
                            playerViewModel.isCheckingHiResAvailability
                                ? "Checking Hi-Res..." : "Check Hi-Res Availability",
                            systemImage: "waveform.badge.magnifyingglass"
                        )
                    }
                    .disabled(
                        playerViewModel.isCheckingHiResAvailability
                            || playerViewModel.currentVideoId == nil)

                    if playerViewModel.canSwitchToHiResVersion {
                        Button {
                            playerViewModel.switchToHiResVersionIfAvailable()
                        } label: {
                            Label("Switch to Hi-Res", systemImage: "arrow.up.circle")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
            .foregroundStyle(.white)
            .font(.title2)
            .frame(alignment: .trailing)
        }
        .frame(height: 60)
        .padding(.top, 80)

    }
}

// MARK: - Progress Section (Fast updates isolated)

struct NowPlayingProgressSection: View {
    @Environment(PlaybackServices.self) private var playbackServices
    private var playerViewModel: any PlayerViewModelInterface { playbackServices.playerViewModel }

    var body: some View {
        MusicProgressScrubber(
            mediaID: playerViewModel.currentVideoId,
            currentTime: playerViewModel.currentTime,
            duration: playerViewModel.duration,
            onSeek: { newTime in
                playerViewModel.seek(to: newTime)
            }
        )
        .frame(height: 30)

    }
}

// MARK: - Controls Section

struct NowPlayingControls: View {
    @Environment(PlaybackServices.self) private var playbackServices
    private var playerViewModel: any PlayerViewModelInterface { playbackServices.playerViewModel }
    let size: CGSize
    let safeArea: EdgeInsets

    var body: some View {
        VStack {
            NowPlayingProgressSection()

            Spacer(minLength: 0)

            HStack(spacing: size.width * 0.18) {
                PreviousButton()
                    .sensoryFeedback(.impact, trigger: playerViewModel.currentVideoId)

                TogglePlayPauseButton()
                    .disabled(playerViewModel.currentVideoId == nil)
                    .sensoryFeedback(.selection, trigger: playerViewModel.isPlaying)

                ForwardButton()
                    .sensoryFeedback(.impact, trigger: playerViewModel.currentVideoId)
            }
            .foregroundColor(.white)

            Spacer(minLength: 0)

            VolumeSlider()
                .frame(height: 30)

            Spacer(minLength: 0)

            NowPlayingFooter(size: size, safeArea: safeArea)
        }

    }
}

// MARK: - Footer Section

struct NowPlayingFooter: View {
    @Environment(PlaybackServices.self) private var playbackServices
    private var playerViewModel: any PlayerViewModelInterface { playbackServices.playerViewModel }
    let size: CGSize
    let safeArea: EdgeInsets

    var body: some View {
        HStack(alignment: .top, spacing: size.width * 0.18) {
            Button {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    playerViewModel.isLyricsVisible.toggle()
                }
            } label: {
                Image(
                    systemName: playerViewModel.isLyricsVisible
                        ? "quote.bubble.fill" : "quote.bubble"
                )
                .font(.title2)
            }

            AirPlayButton(activeTintColor: playerViewModel.currentAccentColor.uiColor)
                .frame(width: 48, height: 48)
                .padding(.top, -13)

            Button {
                // Queue action
            } label: {
                Image(systemName: "list.bullet")
                    .font(.title2)
            }
        }
        .foregroundColor(.white)
        .blendMode(.overlay)

    }
}

// MARK: - Helper Components

struct NowPlayingInfoBadge: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .lineLimit(1)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.white.opacity(0.2), in: Capsule())
            .foregroundStyle(.white)

    }
}

// MARK: - Lyrics Section

struct LyricsView: View {
    @Environment(PlaybackServices.self) private var playbackServices
    private var playerViewModel: any PlayerViewModelInterface { playbackServices.playerViewModel }

    var body: some View {
        ZStack {
            switch playerViewModel.lyricsState {
            case .idle:
                Color.clear
            case .loading:
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
            case .synced:
                SyncedLyricsView()
            case .plain:
                PlainLyricsView()
            case .unavailable(let message):
                VStack(spacing: 16) {
                    Image(systemName: "quote.bubble.rtl.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.white.opacity(0.15))

                    Text(message)
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                }
                .padding(30)
            }
        }

    }
}

struct SyncedLyricsView: View {
    @Environment(PlaybackServices.self) private var playbackServices
    private var playerViewModel: any PlayerViewModelInterface { playbackServices.playerViewModel }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    ForEach(Array(playerViewModel.syncedLyricsLines.enumerated()), id: \.element.id) { index, line in
                        LyricLineView(
                            line: line,
                            isActive: isLineActive(line),
                            distance: distanceToActiveLine(index)
                        )
                        .id(line.id)
                    }
                }
                .padding(.vertical, 180)
                .padding(.horizontal, 20)
            }
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.15),
                        .init(color: .black, location: 0.85),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .onChange(of: playerViewModel.currentSyncedLyricIndex) { oldValue, newValue in
                if let index = newValue, playerViewModel.syncedLyricsLines.indices.contains(index) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0)) {
                        proxy.scrollTo(playerViewModel.syncedLyricsLines[index].id, anchor: .center)
                    }
                }
            }
        }

    }

    private func isLineActive(_ line: Services.TimedLyricLine) -> Bool {
        guard let index = playerViewModel.currentSyncedLyricIndex else { return false }
        return playerViewModel.syncedLyricsLines[index].id == line.id
    }

    private func distanceToActiveLine(_ index: Int) -> Int {
        guard let currentIndex = playerViewModel.currentSyncedLyricIndex else { return index }
        return abs(index - currentIndex)
    }
}

struct LyricLineView: View {
    let line: Services.TimedLyricLine
    let isActive: Bool
    let distance: Int
    @Environment(PlaybackServices.self) private var playbackServices
    private var playerViewModel: any PlayerViewModelInterface { playbackServices.playerViewModel }

    var body: some View {
        Group {
            if isActive, let syllables = line.syllables, !syllables.isEmpty {
                syllablesText(currentTime: playerViewModel.currentTime)
            } else {
                Text(line.text)
                    .foregroundStyle(isActive ? .white : .white.opacity(opacityForDistance))
            }
        }
        .font(.system(size: 34, weight: .heavy, design: .rounded))
        .blur(radius: blurForDistance)
        .scaleEffect(scaleForDistance, anchor: .leading)
        .shadow(color: isActive ? .white.opacity(0.3) : .clear, radius: 10, x: 0, y: 0)
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
        .contentShape(Rectangle())
        .onTapGesture {
            playerViewModel.seek(to: line.timestamp)
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.75), value: isActive)
        .animation(.spring(response: 0.6, dampingFraction: 0.75), value: distance)
    }

    private func syllablesText(currentTime: TimeInterval) -> Text {
        guard let syllables = line.syllables else { return Text(line.text) }
        
        var combinedText = Text("")
        for (index, syllable) in syllables.enumerated() {
            let isSyllableActive = currentTime >= syllable.timestamp
            let color = isSyllableActive ? Color.white : Color.white.opacity(0.3)
            
            var sylText = Text(syllable.text).foregroundStyle(color)
            if !syllable.isPartOfWord && index < syllables.count - 1 {
                sylText = sylText + Text(" ")
            }
            combinedText = combinedText + sylText
        }
        return combinedText
    }

    private var opacityForDistance: Double {
        switch distance {
        case 0: return 1.0
        case 1: return 0.5
        case 2: return 0.25
        default: return 0.15
        }
    }

    private var blurForDistance: CGFloat {
        switch distance {
        case 0: return 0
        case 1: return 1.5
        case 2: return 3.0
        default: return 4.5
        }
    }

    private var scaleForDistance: CGFloat {
        switch distance {
        case 0: return 1.0
        case 1: return 0.95
        case 2: return 0.9
        default: return 0.85
        }
    }
}

struct PlainLyricsView: View {
    @Environment(PlaybackServices.self) private var playbackServices
    private var playerViewModel: any PlayerViewModelInterface { playbackServices.playerViewModel }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            Text(playerViewModel.plainLyricsText ?? "")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.leading)
                .padding(30)
                .frame(maxWidth: .infinity, alignment: .leading)
        }

    }
}
