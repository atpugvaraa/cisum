//
//  MiniMusicProgress.swift
//  cisum
//
//  Created by Aarav Gupta (github.com/atpugvaraa) on 04/05/25.
//

import SwiftUI

struct MiniPlayerMusicProgress: View {
    @Binding var value: TimeInterval
    let inRange: ClosedRange<TimeInterval>
    var activeFillColor: Color = .white
    var fillColor: Color = .white.opacity(0.5)
    var emptyColor: Color = .white.opacity(0.3)
    let height: CGFloat = 55
    var onEditingChanged: (Bool) -> Void = { _ in }
    
    // Convenience initializer that only requires current time and duration
    init(currentTime: Binding<TimeInterval>, duration: TimeInterval) {
        self._value = currentTime
        self.inRange = 0...duration
    }
    
    // Original initializer with all parameters
    init(
        value: Binding<TimeInterval>,
        inRange: ClosedRange<TimeInterval>,
        activeFillColor: Color = .white,
        fillColor: Color = .white.opacity(0.5),
        emptyColor: Color = .white.opacity(0.3),
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self._value = value
        self.inRange = inRange
        self.activeFillColor = activeFillColor
        self.fillColor = fillColor
        self.emptyColor = emptyColor
        self.onEditingChanged = onEditingChanged
    }
    
    private var progress: Double {
        guard inRange.upperBound > inRange.lowerBound else { return 0 }
        let clampedValue = max(inRange.lowerBound, min(value, inRange.upperBound))
        return (clampedValue - inRange.lowerBound) / (inRange.upperBound - inRange.lowerBound)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 15)
                    .stroke(lineWidth: 3)
                    .fill(emptyColor)
                    .frame(height: height)

                // Filled track (masked to simulate fill)
                RoundedRectangle(cornerRadius: 15)
                    .stroke(lineWidth: 3)
                    .fill(fillColor)
                    .frame(height: height)
                    .mask(
                        HStack {
                            Rectangle()
                                .frame(width: geometry.size.width * progress)
                            Spacer(minLength: 0)
                        }
                    )
            }
            .clipShape(.rect(cornerRadius: 15))
        }
        .allowsHitTesting(false)
    }
}
