//
//  cisumVolumeSlider.swift
//  cisum
//
//  Created by Aarav Gupta (github.com/atpugvaraa) on 04/05/25.
//

import SwiftUI

struct cisumVolumeSlider: View {
    @State var volume: CGFloat = 0.5
    @State var minVolumeAnimationTrigger: Bool = false
    @State var maxVolumeAnimationTrigger: Bool = false
    let range = 0.0 ... 1

    public var body: some View {
        StretchySlider(
            value: $volume,
            in: range,
            leadingLabel: {
                Image(systemName: "speaker.fill")
                    .padding(.trailing, 10)
                    .symbolEffect(.bounce, value: minVolumeAnimationTrigger)
            },
            trailingLabel: {
                Image(systemName: "speaker.wave.3.fill")
                    .padding(.leading, 10)
                    .symbolEffect(.bounce, value: maxVolumeAnimationTrigger)
            }
        )
        .sliderStyle(.volume)
        .font(.system(size: 14))
        .onChange(of: volume) {
            if volume == range.lowerBound {
                minVolumeAnimationTrigger.toggle()
            }
            if volume == range.upperBound {
                maxVolumeAnimationTrigger.toggle()
            }
        }
        .frame(height: 50)
    }
}

extension cisumSliderConfig {
    static var volume: Self {
        Self(
            labelLocation: .side,
            maxStretch: 10,
            minimumTrackActiveColor: .white,
            minimumTrackInactiveColor: Color(.init(white: 0.784, alpha: 0.816)),
            maximumTrackColor: Color(.init(white: 0.784, alpha: 0.816)),
            blendMode: .overlay,
            syncLabelsStyle: true
        )
    }
}
