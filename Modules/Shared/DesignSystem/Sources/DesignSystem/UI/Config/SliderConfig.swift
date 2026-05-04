import SwiftUI

public struct SliderConfig: Sendable {
    public enum LabelLocation: Sendable {
        case bottom
        case side
        case overlay
    }

    public let labelLocation: LabelLocation
    public let activeHeight: CGFloat
    public let inactiveHeight: CGFloat
    public let growth: CGFloat
    public let stretchNarrowing: CGFloat
    public let maxStretch: CGFloat
    public let pushStretchRatio: CGFloat
    public let pullStretchRatio: CGFloat
    public let minimumTrackActiveColor: Color
    public let minimumTrackInactiveColor: Color
    public let maximumTrackColor: Color
    public let blendMode: BlendMode
    public let syncLabelsStyle: Bool
    public let defaultSensoryFeedback: Bool

    public init(
        labelLocation: LabelLocation = .side,
        activeHeight: CGFloat = 17,
        inactiveHeight: CGFloat = 7,
        growth: CGFloat = 9,
        stretchNarrowing: CGFloat = 4,
        maxStretch: CGFloat = 9,
        pushStretchRatio: CGFloat = 0.2,
        pullStretchRatio: CGFloat = 0.5,
        minimumTrackActiveColor: Color = .blue,
        minimumTrackInactiveColor: Color = .gray,
        maximumTrackColor: Color = .gray.opacity(0.3),
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

    public static var volume: Self {
        Self(
            labelLocation: .side,
            maxStretch: 10,
            minimumTrackActiveColor: .white,
            minimumTrackInactiveColor: .white.opacity(0.2),
            maximumTrackColor: .white.opacity(0.2),
            blendMode: .overlay,
            syncLabelsStyle: true
        )
    }

    public static var miniPlayerProgress: Self {
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

    public static var playbackProgress: Self {
        Self(
            labelLocation: .bottom,
            maxStretch: 10,
            minimumTrackActiveColor: .white,
            minimumTrackInactiveColor: .white.opacity(0.5),
            maximumTrackColor: .white.opacity(0.5),
            blendMode: .overlay,
            syncLabelsStyle: true
        )
    }
}
