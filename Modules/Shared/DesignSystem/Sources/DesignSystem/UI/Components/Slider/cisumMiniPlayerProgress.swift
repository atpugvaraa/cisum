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

    var body: some View {
        StretchySlider(value: $currentTime, in: range)
            .sliderStyle(.miniPlayerProgress)
            .frame(height: 55)
            .transformEffect(.identity)
            .allowsHitTesting(false)
    }
}

#endif
