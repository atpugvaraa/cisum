//
//  cisumMusicProgressScrubber.swift
//  cisum
//
//  Created by Aarav Gupta (github.com/atpugvaraa) on 04/05/25.
//

#if os(iOS)
import SwiftUI

struct cisumMusicProgressScrubber: View {
    let currentTime: Double
    let duration: Double
    let onSeek: (Double) -> Void
    @State private var sliderProgress: Double = 0
    @State private var isEditing = false

    let onEditingChanged: (Bool) -> Void
    
    init(
        currentTime: Double,
        duration: Double,
        onSeek: @escaping (Double) -> Void,
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.currentTime = currentTime
        self.duration = duration
        self.onSeek = onSeek
        self.onEditingChanged = onEditingChanged
    }

    #if DEBUG
    @ObserveInjection var forceRedraw
    #endif

    var body: some View {
        let progress = normalizedProgress

        StretchySlider(
            value: $sliderProgress,
            in: 0...1,
            leadingLabel: {
                label(elapsedDuration)
            },
            trailingLabel: {
                label(totalDuration)
            },
            onEditingChanged: { editing in
                isEditing = editing
                onEditingChanged(editing)
            }
        )
        .sliderStyle(.playbackProgress)
        .frame(height: 35)
        .transformEffect(.identity)
        .onAppear {
            sliderProgress = progress
        }
        .onChange(of: currentTime) { _, _ in
            guard !isEditing else { return }
            sliderProgress = normalizedProgress
        }
        .onChange(of: duration) { _, _ in
            guard !isEditing else { return }
            sliderProgress = normalizedProgress
        }
        .onChange(of: isEditing) { _, newValue in
            if !newValue, duration > 0 {
                onSeek(max(0, min(sliderProgress, 1)) * duration)
            }
        }
        .enableInjection()
    }
}

private extension cisumMusicProgressScrubber {
    func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
    }

    var normalizedProgress: Double {
        guard duration.isFinite, duration > 0, currentTime.isFinite else { return 0 }
        return min(max(currentTime / duration, 0), 1)
    }

    var elapsedDuration: String {
        guard currentTime.isFinite else { return "0:00" }
        return currentTime.asTimeString(style: .positional)
    }

    var totalDuration: String {
        guard duration.isFinite else { return "0:00" }
        return duration.asTimeString(style: .positional)
    }
}

extension cisumSliderConfig {
    static var playbackProgress: Self {
        Self(
            labelLocation: .bottom,
            maxStretch: 0,
            minimumTrackActiveColor: Color(.white),
            minimumTrackInactiveColor: Color(.init(white: 0.784, alpha: 0.816)),
            maximumTrackColor: Color(.init(white: 0.784, alpha: 0.816)),
            blendMode: .overlay,
            syncLabelsStyle: true
        )
    }
}
#endif
