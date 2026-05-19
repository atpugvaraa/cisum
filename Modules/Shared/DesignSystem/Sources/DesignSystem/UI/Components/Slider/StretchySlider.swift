//
//  StretchySlider.swift
//  cisum
//
//  Created by Aarav Gupta (github.com/atpugvaraa) on 04/05/25.
//

#if os(iOS) || os(macOS)
import SwiftUI
import Utilities

public struct StretchySlider<LeadingContent: View, TrailingContent: View>: View {
    @Binding var value: Double
    /// View Properties
    private let range: ClosedRange<Double>
    private let leadingLabel: LeadingContent?
    private let trailingLabel: TrailingContent?
    private let onEditingChanged: (Bool) -> Void
    
    @Environment(\.sliderConfig) var config
    
    @State var progress: CGFloat = .zero
    @State private var dragOffset: CGFloat = .zero
    @State private var lastDragOffset: CGFloat = .zero
    let limitation: CGFloat = 0.1
    
    @State private var stretchingValue: CGFloat = 0
    @State private var viewSize: CGSize = .zero
    
    @GestureState var isActive: Bool = false
    
    public init(
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        leadingLabel: (() -> LeadingContent)? = nil,
        trailingLabel: (() -> TrailingContent)? = nil,
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        _value = value
        self.range = range
        self.leadingLabel = leadingLabel?()
        self.trailingLabel = trailingLabel?()
        self.onEditingChanged = onEditingChanged
    }
    
    public var body: some View {
        Group {
            if config.labelLocation == .bottom {
                bottomLabeledSlider
            } else if config.labelLocation == .side {
                sideLabeledSlider
            } else if config.labelLocation == .overlay {
                miniPlayerProgress
            }
        }
        .animation(.smooth(duration: 0.25, extraBounce: 0.05), value: isActive)
        .sensoryFeedback(.increase, trigger: isValueExtreme) { true && $1 }
        
    }
    
    /// Calculating Progess
    private func calculateProgress(orientationSize: CGFloat) {
        let topAndTrailingExcessOffset = orientationSize + (dragOffset - orientationSize) * 0.15
        let bottomAndLeadingExcessOffset = dragOffset < 0 ? (dragOffset * 0.15) : dragOffset
        
        let progress =
        (dragOffset > orientationSize
         ? topAndTrailingExcessOffset : bottomAndLeadingExcessOffset) / orientationSize
        
        self.progress =
        progress < 0
        ? (-progress > limitation ? -limitation : progress)
        : (progress > (1.0 + limitation) ? (1.0 + limitation) : progress)
    }
}

extension StretchySlider {
    public var miniPlayerProgress: some View {
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
                    .fill(
                        isActive
                        ? config.minimumTrackActiveColor : config.minimumTrackInactiveColor
                    )
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

    fileprivate var slider: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let orientationSize = size.width
            let progressValue = (max(progress, .zero)) * orientationSize
            
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(config.maximumTrackColor)
                    .blendMode(config.blendMode)
                
                Rectangle()
                    .fill(
                        isActive
                        ? config.minimumTrackActiveColor : config.minimumTrackInactiveColor
                    )
                    .frame(width: progressValue, height: nil)
                    .blendMode(isActive ? .normal : config.blendMode)
            }
            .clipShape(.rect(cornerRadius: 15))
            .contentShape(.rect(cornerRadius: 15))
            .frame(
                height: isActive
                ? config.activeHeight - abs(normalizedStretchingValue)
                * config.stretchNarrowing : config.inactiveHeight
            )
            .optionalSizingModifiers(
                size: size,
                progress: progress,
                orientationSize: orientationSize
            )
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .updating($isActive) { _, state, _ in
                        state = true
                        onEditingChanged(true)
                    }
                    .onChanged {
                        let translation = $0.translation
                        let movement = translation.width + lastDragOffset
                        dragOffset = movement
                        calculateProgress(orientationSize: orientationSize)
                        
                        let liveValue = Double(max(min(progress, 1.0), 0.0))
                        if abs(value - liveValue) > 0.0001 {
                            value = liveValue
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.smooth) {
                            dragOffset =
                            dragOffset > orientationSize
                            ? orientationSize : (dragOffset < 0 ? 0 : dragOffset)
                            calculateProgress(orientationSize: orientationSize)
                        }
                        
                        lastDragOffset = dragOffset
                        onEditingChanged(false)
                    }
            )
            //            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
            //                .updating($isActive) { value, state, transaction in
            //                    state = true
            //                }
            //                .onChanged { gesture in
            //                    let width = bounds.size.width
            //                    let dragTranslation = gesture.translation.width / width
            //                    localTempProgress = CGFloat(max(min(dragTranslation, 1), -1))
            //                    let prg = max(min((localRealProgress + localTempProgress), 1), 0)
            //                    progressDuration = max(min(inRange.upperBound * TimeInterval(prg), inRange.upperBound), 0)
            //                    let newValue = max(min(getPrgValue(), inRange.upperBound), inRange.lowerBound)
            //                    if newValue.isFinite && !newValue.isNaN {
            //                        value = newValue
            //                    }
            //                }
            //                .onEnded { _ in
            //                    localRealProgress = max(min(localRealProgress + localTempProgress, 1), 0)
            //                    localTempProgress = 0
            //                    progressDuration = max(min(inRange.upperBound * TimeInterval(localRealProgress), inRange.upperBound), 0)
            //                    let newValue = max(min(getPrgValue(), inRange.upperBound), inRange.lowerBound)
            //                    if newValue.isFinite && !newValue.isNaN {
            //                        value = newValue
            //                        // Update Seek Value for Player
            //                    }
            //                })
            //            .onChange(of: isActive) { newValue in
            //                let updatedValue = max(min(getPrgValue(), inRange.upperBound), inRange.lowerBound)
            //                if updatedValue.isFinite && !updatedValue.isNaN {
            //                    value = updatedValue
            //                    onEditingChanged(newValue)
            //                }
            //            }
            //            .onAppear {
            //                if inRange.upperBound.isFinite && !inRange.upperBound.isNaN {
            //                    localRealProgress = CGFloat(getPrgPercentage(value))
            //                    progressDuration = max(min(inRange.upperBound * TimeInterval(localRealProgress), inRange.upperBound), 0)
            //                }
            //            }
            //            .onChange(of: value) { newValue in
            //                if !isActive && newValue.isFinite && !newValue.isNaN {
            //                    localRealProgress = CGFloat(getPrgPercentage(newValue))
            //                    progressDuration = max(min(inRange.upperBound * TimeInterval(localRealProgress), inRange.upperBound), 0)
            //                }
            //            }
            .frame(
                maxWidth: size.width,
                maxHeight: size.height,
                alignment: (progress < 0 ? .trailing : .leading)
            )
            .onChange(of: value, initial: true) { oldValue, newValue in
                /// Initial Progress Settings
                guard value != progress else { return }
                progress = max(min(value, 1.0), .zero)
                dragOffset = progress * orientationSize
                lastDragOffset = dragOffset
            }
            .onChange(of: progress) { oldValue, newValue in
                value = max(min(progress, 1.0), .zero)
            }
        }
    }
    
    fileprivate var isValueExtreme: Bool {
        value == range.lowerBound || value == range.upperBound
    }
    
    @ViewBuilder
    fileprivate func styled<Content: View>(_ content: Content) -> some View {
        if config.syncLabelsStyle {
            ZStack {
                content
                    .foregroundStyle(config.maximumTrackColor)
                    .blendMode(config.blendMode)
                
                content
                    .foregroundStyle(
                        isActive
                        ? config.minimumTrackActiveColor : config.minimumTrackInactiveColor)
            }
            .animation(.bouncy, value: isActive)
            .blendMode(isActive ? .normal : config.blendMode)
            .transformEffect(.identity)
        } else {
            content
        }
    }
    
    fileprivate var bottomLabeledSlider: some View {
        VStack(spacing: 0) {
            slider
            
            HStack(spacing: 0) {
                let padding = (isActive ? 0 : config.growth) + config.maxStretch
                
                styled(leadingLabel)
                //                    .padding(.leading, padding - leadingStretch)
                    .offset(x: padding - leadingStretch + 3)
                
                Spacer()
                styled(trailingLabel)
                //                    .padding(.trailing, padding - trailingStretch)
                    .offset(x: trailingStretch - padding - 3)
            }
        }
    }
    
    fileprivate var sideLabeledSlider: some View {
        HStack(spacing: 0) {
            let padding = (isActive ? 0 : config.growth) + config.maxStretch
            
            styled(leadingLabel)
                .offset(x: padding - leadingStretch)
            
            slider
            
            styled(trailingLabel)
                .offset(x: trailingStretch - padding)
        }
    }
    
    fileprivate var normalizedStretchingValue: CGFloat {
        guard config.maxStretch != 0 else { return 0 }
        let trackWidth = activeTrackWidth
        guard trackWidth != 0, viewSize.width > config.maxStretch * 2 else { return 0 }
        let maxValue = config.maxStretch / trackWidth / config.pushStretchRatio
        let clamped = min(max(stretchingValue, -maxValue), maxValue)
        return clamped / maxValue
    }
    
    fileprivate var leadingStretch: CGFloat {
        let value = normalizedStretchingValue
        let stretch = abs(value) * config.maxStretch
        return value < 0 ? stretch : -stretch * config.pullStretchRatio
    }
    
    fileprivate var trailingStretch: CGFloat {
        let value = normalizedStretchingValue
        let stretch = abs(value) * config.maxStretch
        return stretchingValue > 0 ? stretch : -stretch * config.pullStretchRatio
    }
    
    fileprivate func normalized(_ value: CGFloat) -> CGFloat {
        (value - range.lowerBound) / range.distance
    }
    
    fileprivate var activeTrackWidth: CGFloat {
        trackWidth(for: viewSize.width, active: true)
    }
    
    fileprivate func trackWidth(for viewWidth: CGFloat, active: Bool) -> CGFloat {
        max(0, viewWidth - config.maxStretch * 2 - (active ? 0 : config.growth * 2))
    }
}

// MARK: Convenience initializers
extension StretchySlider where LeadingContent == EmptyView {
    public init(
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        trailingLabel: (() -> TrailingContent)? = nil,
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        _value = value
        self.range = range
        leadingLabel = nil
        self.trailingLabel = trailingLabel?()
        self.onEditingChanged = onEditingChanged
    }
}

extension StretchySlider where TrailingContent == EmptyView {
    public init(
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        leadingLabel: (() -> LeadingContent)? = nil,
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        _value = value
        self.range = range
        self.leadingLabel = leadingLabel?()
        trailingLabel = nil
        self.onEditingChanged = onEditingChanged
    }
}

extension StretchySlider where LeadingContent == EmptyView, TrailingContent == EmptyView {
    public init(
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        _value = value
        self.range = range
        leadingLabel = nil
        trailingLabel = nil
        self.onEditingChanged = onEditingChanged
    }
}

extension View {
    @ViewBuilder
    fileprivate func optionalSizingModifiers(
        size: CGSize, progress: CGFloat, orientationSize: CGFloat
    ) -> some View {
        let topAndTrailingScale = 1 + (progress - 1) * 0.15
        let bottomAndLeadingScale = 1 + (progress) * 0.15
        
        self
            .frame(width: progress < 0 ? size.width + (-progress * size.width) : nil)
            .scaleEffect(
                x: 1,
                y: (progress > 1
                    ? topAndTrailingScale : (progress < 0 ? bottomAndLeadingScale : 1)),
                anchor: (progress < 0 ? .trailing : .leading)
            )
    }
}
#endif
