import SwiftUI
import Utilities
import CoreGraphics

public struct MusicProgressScrubber: View {
    let mediaID: String?
    let currentTime: Double
    let duration: Double
    let onSeek: (Double) -> Void
    @State private var sliderProgress: Double = 0
    @State private var displayedCurrentTime: Double = 0
    @State private var displayedDuration: Double = 0
    @State private var isEditing = false
    @State private var pendingSeekTime: Double?

    let onEditingChanged: (Bool) -> Void

    public init(
        mediaID: String?,
        currentTime: Double,
        duration: Double,
        onSeek: @escaping (Double) -> Void,
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.mediaID = mediaID
        self.currentTime = currentTime
        self.duration = duration
        self.onSeek = onSeek
        self.onEditingChanged = onEditingChanged
    }

    

    public var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .onAppear {
                syncDisplayState(animated: false)
            }
            .onChange(of: mediaID) { _, _ in
                isEditing = false
                pendingSeekTime = nil
                syncDisplayState(animated: false)
            }
            .onChange(of: currentTime) { _, _ in
                guard !isEditing else { return }
                if let pendingSeekTime {
                    let observedCurrentTime = currentTime.isFinite ? currentTime : 0
                    guard abs(observedCurrentTime - pendingSeekTime) <= 0.35 else { return }
                    self.pendingSeekTime = nil
                }
                syncDisplayState(animated: true)
            }
            .onChange(of: duration) { _, _ in
                guard !isEditing else { return }
                if let pendingSeekTime {
                    let observedCurrentTime = currentTime.isFinite ? currentTime : 0
                    guard abs(observedCurrentTime - pendingSeekTime) <= 0.35 else { return }
                    self.pendingSeekTime = nil
                }
                syncDisplayState(animated: true)
            }

    }
}

extension MusicProgressScrubber {
    @ViewBuilder
    fileprivate var content: some View {
        #if os(iOS)
            StretchySlider(
                value: $sliderProgress,
                in: 0.0...1.0,
                leadingLabel: {
                    label(elapsedDuration)
                },
                trailingLabel: {
                    label(totalDuration)
                },
                onEditingChanged: { editing in
                    if editing {
                        beginEditing()
                    } else {
                        commitSeek()
                        endEditing()
                    }
                }
            )
            .sliderStyle(SliderConfig.playbackProgress)
            .frame(height: 35)
            .transformEffect(CGAffineTransform.identity)
        #elseif os(macOS)
            GeometryReader { proxy in
                let trackWidth = max(proxy.size.width, 1)

                VStack(spacing: 6) {
                    macOSProgressTrack(trackWidth: trackWidth)

                    HStack {
                        label(elapsedDuration)
                        Spacer(minLength: 0)
                        label(totalDuration)
                    }
                }
                .foregroundStyle(.white.opacity(0.94))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .gesture(macOSScrubGesture(trackWidth: trackWidth))
            }
            .frame(height: 42)
        #endif
    }

    fileprivate func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .contentTransition(.numericText())
    }

    fileprivate var normalizedProgress: Double {
        normalizedProgress(for: currentTime, duration: duration)
    }

    fileprivate func normalizedProgress(for currentTime: Double, duration: Double) -> Double {
        guard duration.isFinite, duration > 0, currentTime.isFinite else { return 0 }
        return min(max(currentTime / duration, 0), 1)
    }

    fileprivate func normalizedProgress(for locationX: CGFloat, width: CGFloat) -> Double {
        guard width > 0 else { return 0 }
        return min(max(Double(locationX / width), 0), 1)
    }

    fileprivate func clampedProgress(_ progress: Double) -> Double {
        min(max(progress, 0), 1)
    }

    fileprivate var elapsedDuration: String {
        guard displayedCurrentTime.isFinite else { return "0:00" }
        return displayedCurrentTime.asTimeString(style: .positional)
    }

    fileprivate var totalDuration: String {
        guard displayedDuration.isFinite else { return "0:00" }
        return displayedDuration.asTimeString(style: .positional)
    }

    fileprivate func syncDisplayState(animated: Bool) {
        let nextDuration = duration.isFinite ? duration : 0
        let nextCurrentTime = currentTime.isFinite ? currentTime : 0
        let nextProgress = normalizedProgress(for: nextCurrentTime, duration: nextDuration)

        if animated {
            withAnimation(.linear(duration: 0.12)) {
                displayedDuration = nextDuration
                displayedCurrentTime = nextCurrentTime
                sliderProgress = nextProgress
            }
        } else {
            displayedDuration = nextDuration
            displayedCurrentTime = nextCurrentTime
            sliderProgress = nextProgress
        }
    }

    fileprivate func beginEditing() {
        guard !isEditing else { return }
        isEditing = true
        onEditingChanged(true)
    }

    fileprivate func endEditing() {
        guard isEditing else { return }
        isEditing = false
        onEditingChanged(false)
    }

    fileprivate func commitSeek() {
        guard duration.isFinite, duration > 0 else { return }
        let seekTime = clampedProgress(sliderProgress) * duration
        displayedCurrentTime = seekTime
        displayedDuration = duration
        sliderProgress = clampedProgress(sliderProgress)

        if let pendingSeekTime, abs(pendingSeekTime - seekTime) <= 0.001 {
            return
        }

        pendingSeekTime = seekTime
        onSeek(seekTime)
    }

    fileprivate func updateProgress(for progress: Double) {
        let clamped = clampedProgress(progress)
        sliderProgress = clamped
        displayedCurrentTime = clamped * (duration.isFinite ? duration : 0)
        displayedDuration = duration.isFinite ? duration : 0
    }

    #if os(macOS)
        @ViewBuilder
        fileprivate func macOSProgressTrack(trackWidth: CGFloat) -> some View {
            let progress = clampedProgress(sliderProgress)
            let fillWidth = max(0, min(trackWidth * progress, trackWidth))

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(.white.opacity(0.16))

                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(.white.opacity(isEditing ? 0.98 : 0.9))
                    .frame(width: fillWidth)
            }
            .frame(height: 6)
        }

        fileprivate func macOSScrubGesture(trackWidth: CGFloat) -> some Gesture {
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { value in
                    let progress = normalizedProgress(for: value.location.x, width: trackWidth)
                    updateProgress(for: progress)

                    if !isEditing {
                        beginEditing()
                        commitSeek()
                    }
                }
                .onEnded { value in
                    let progress = normalizedProgress(for: value.location.x, width: trackWidth)
                    updateProgress(for: progress)
                    commitSeek()
                    endEditing()
                }
        }
    #endif
}
