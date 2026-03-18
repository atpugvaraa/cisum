//
//  cisumMiniPlayerProgress.swift
//  cisum
//
//  Created by Aarav Gupta (github.com/atpugvaraa) on 04/05/25.
//

#if os(iOS)

import SwiftUI

struct cisumMiniPlayerProgress: View {
    @Binding var currentTime: Double
    let range: ClosedRange<Double>
    
    init(
        currentTime: Binding<Double>,
        inRange range: ClosedRange<Double>
    ) {
        self._currentTime = currentTime
        self.range = range
    }
    
    #if DEBUG
    @ObserveInjection var forceRedraw
    #endif

    var body: some View {
        StretchySlider(value: $currentTime, in: range)
            .sliderStyle(.miniPlayerProgress)
            .frame(height: 55)
            .transformEffect(.identity)
            .allowsHitTesting(false)
        .enableInjection()
    }
}

extension StretchySlider {
    var miniPlayerProgress: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let orientationSize = size.width
            let progressValue = (max(progress, .zero)) * orientationSize
            
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 15)
                    .stroke(lineWidth: 3)
                    .fill(config.maximumTrackColor)
                    .blendMode(config.blendMode)
                
                // Filled track (masked to simulate fill)
                RoundedRectangle(cornerRadius: 15)
                    .stroke(lineWidth: 3)
                    .fill(isActive ? config.minimumTrackActiveColor : config.minimumTrackInactiveColor)
                    .frame(width: progressValue, height: nil)
                    .blendMode(isActive ? .normal : config.blendMode)
                    .mask(
                        HStack {
                            Rectangle()
                                .frame(width: size.width * progress)
                            Spacer(minLength: 0)
                        }
                    )
            }
        }
    }
}

extension cisumSliderConfig {
    static var miniPlayerProgress: Self {
        Self(
            labelLocation: .overlay,
            maxStretch: 0,
            minimumTrackActiveColor: .white,
            minimumTrackInactiveColor: .white.opacity(0.5),
            maximumTrackColor: .white.opacity(0.5),
            blendMode: .overlay,
            syncLabelsStyle: true
        )
    }
}

#endif
