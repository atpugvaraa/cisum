//
//  cisumSliderConfig.swift
//  cisum
//
//  Created by Aarav Gupta (github.com/atpugvaraa) on 09/05/25.
//

#if os(iOS)
import SwiftUI

struct cisumSliderConfig {
    enum LabelLocation {
        case bottom
        case side
        case overlay
    }

    let labelLocation: LabelLocation
    let activeHeight: CGFloat
    let inactiveHeight: CGFloat
    let growth: CGFloat
    let stretchNarrowing: CGFloat
    let maxStretch: CGFloat
    let pushStretchRatio: CGFloat
    let pullStretchRatio: CGFloat
    let minimumTrackActiveColor: Color
    let minimumTrackInactiveColor: Color
    let maximumTrackColor: Color
    let blendMode: BlendMode
    let syncLabelsStyle: Bool
    let defaultSensoryFeedback: Bool

    init(
        labelLocation: cisumSliderConfig.LabelLocation = .side,
        activeHeight: CGFloat = 17,
        inactiveHeight: CGFloat = 7,
        growth: CGFloat = 9,
        stretchNarrowing: CGFloat = 4,
        maxStretch: CGFloat = 9,
        pushStretchRatio: CGFloat = 0.2,
        pullStretchRatio: CGFloat = 0.5,
        minimumTrackActiveColor: Color = .init(UIColor.tintColor),
        minimumTrackInactiveColor: Color = .init(UIColor.systemGray3),
        maximumTrackColor: Color = .init(UIColor.systemGray6),
        blendMode: BlendMode = .normal,
        syncLabelsStyle: Bool = false,
        defaultSensoryFeedback: Bool = true
    ) {
        self.labelLocation = labelLocation
        self.activeHeight = activeHeight
        self.inactiveHeight = inactiveHeight
        self.growth = growth
        self.stretchNarrowing = stretchNarrowing
        self.maxStretch = maxStretch
        self.pushStretchRatio = pushStretchRatio
        self.pullStretchRatio = pullStretchRatio
        self.minimumTrackActiveColor = minimumTrackActiveColor
        self.minimumTrackInactiveColor = minimumTrackInactiveColor
        self.maximumTrackColor = maximumTrackColor
        self.blendMode = blendMode
        self.syncLabelsStyle = syncLabelsStyle
        self.defaultSensoryFeedback = defaultSensoryFeedback
    }
}
#endif
