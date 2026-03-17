//
//  cisumVolumeSlider.swift
//  cisum
//
//  Created by Aarav Gupta (github.com/atpugvaraa) on 04/05/25.
//

import SwiftUI

struct cisumVolumeSlider: View {
    @Binding var volume: Double
    
    @State var minVolumeAnimationTrigger: Bool = false
    @State var maxVolumeAnimationTrigger: Bool = false
    
    let range: ClosedRange<Double>
    let onEditingChanged: (Bool) -> Void
    
    init(
        volume: Binding<Double>,
        in range: ClosedRange<Double> = 0.0...1.0,
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self._volume = volume
        self.range = range
        self.onEditingChanged = onEditingChanged
    }

    #if DEBUG
    @ObserveInjection var forceRedraw
    #endif

    public var body: some View {
        StretchySlider(
            value: $volume,
            in: range,
            leadingLabel: {
                Image(systemName: "speaker.fill")
                    .padding(.trailing, 20)
                    .symbolEffect(.bounce, value: minVolumeAnimationTrigger)
            },
            trailingLabel: {
                Image(systemName: "speaker.wave.3.fill")
                    .padding(.leading, 20)
                    .symbolEffect(.bounce, value: maxVolumeAnimationTrigger)
            },
            onEditingChanged: onEditingChanged
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
        .enableInjection()
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
