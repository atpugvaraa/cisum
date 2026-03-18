//
//  cisumMusicProgressScrubber.swift
//  cisum
//
//  Created by Aarav Gupta (github.com/atpugvaraa) on 04/05/25.
//

#if os(iOS)
import SwiftUI

struct cisumMusicProgressScrubber: View {
    @Binding var currentTime: Double
    let range: ClosedRange<Double>
    let onEditingChanged: (Bool) -> Void
    
    init(
        currentTime: Binding<Double>,
        inRange range: ClosedRange<Double>,
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self._currentTime = currentTime
        self.range = range
        self.onEditingChanged = onEditingChanged
    }

    #if DEBUG
    @ObserveInjection var forceRedraw
    #endif

    var body: some View {
        StretchySlider(
            value: $currentTime,
            in: range,
            leadingLabel: {
                label(leadingDuration)
            },
            trailingLabel: {
                label(trailingDuration)
            },
            onEditingChanged: onEditingChanged
        )
        .sliderStyle(.playbackProgress)
        .frame(height: 35)
        .transformEffect(.identity)
        .enableInjection()
    }
}

private extension cisumMusicProgressScrubber {
    func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
    }

    var leadingDuration: String {
        currentTime.asTimeString(style: .positional)
    }

    var trailingDuration: String {
        ((range.upperBound - currentTime) * -1.0).asTimeString(style: .positional)
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
