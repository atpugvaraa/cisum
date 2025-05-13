//
//  cisumMusicProgressScrubber.swift
//  cisum
//
//  Created by Aarav Gupta (github.com/atpugvaraa) on 04/05/25.
//

import SwiftUI

struct cisumMusicProgressScrubber: View {
    @State var currentTime: CGFloat = 60
    let range = 0.0 ... 194

    var body: some View {
        StretchySlider(
            value: $currentTime,
            in: range,
            leadingLabel: {
                label(leadingDuration)
            },
            trailingLabel: {
                label(trailingDuration)
            }
        )
        .sliderStyle(.playbackProgress)
        .frame(height: 60)
        .transformEffect(.identity)
    }
}

private extension cisumMusicProgressScrubber {
    func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .padding(.top, 11)
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
