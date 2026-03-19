//
//  ScrollViewModifiers.swift
//  cisum
//
//  Created by Aarav Gupta on 15/03/26.
//

import SwiftUI

#if os(iOS)
struct ScrollGeometryReader {
    var contentOffset: CGPoint
    var contentInsets: EdgeInsets
}

struct ScrollOffsetChangeModifier<Value: Equatable>: ViewModifier {
    let transform: (ScrollGeometryReader) -> Value
    let action: (Value, Value) -> Void

    @State private var previousValue: Value?
    @State private var latestOffsetY: CGFloat = 0

    #if DEBUG
    @ObserveInjection var forceRedraw
    #endif

    func body(content: Content) -> some View {
        content
            .overlay {
                ScrollOffsetObserver { yOffset in
                    latestOffsetY = yOffset
                }
                .frame(width: 0, height: 0)
            }
            .onChange(of: latestOffsetY) { _, yOffset in
                let geometry = ScrollGeometryReader(
                    contentOffset: CGPoint(x: 0, y: yOffset),
                    contentInsets: EdgeInsets()
                )
                let newValue = transform(geometry)

                if let oldValue = previousValue, oldValue != newValue {
                    action(oldValue, newValue)
                }
                previousValue = newValue
            }
            .enableInjection()
    }
}

struct ScrollPhaseUpdateModifier: ViewModifier {
    let action: (ScrollPhases, ScrollPhases) -> Void

    @State private var currentPhase: ScrollPhases = .idle
    @State private var hasSeenScrollEvent = false
    @State private var deceleratingWorkItem: DispatchWorkItem?
    @State private var idleWorkItem: DispatchWorkItem?

    private func transition(to newPhase: ScrollPhases) {
        guard currentPhase != newPhase else { return }
        let oldPhase = currentPhase
        currentPhase = newPhase
        action(oldPhase, newPhase)
    }

    private func scheduleIdleTransition(after delay: TimeInterval = 0.2) {
        idleWorkItem?.cancel()

        let workItem = DispatchWorkItem {
            if currentPhase != .idle {
                transition(to: .idle)
            }
        }

        idleWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func scheduleDeceleratingTransition(after delay: TimeInterval = 0.06) {
        deceleratingWorkItem?.cancel()

        let workItem = DispatchWorkItem {
            if currentPhase == .interacting {
                transition(to: .decelerating)
            }
        }

        deceleratingWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func handleScrollActivity() {
        if !hasSeenScrollEvent {
            hasSeenScrollEvent = true
            return
        }

        transition(to: .interacting)
        scheduleDeceleratingTransition(after: 0.08)
        scheduleIdleTransition(after: 0.22)
    }

    #if DEBUG
    @ObserveInjection var forceRedraw
    #endif

    func body(content: Content) -> some View {
        content
            .overlay {
                ScrollOffsetObserver { _ in
                    handleScrollActivity()
                }
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
            }
            .onDisappear {
                deceleratingWorkItem?.cancel()
                idleWorkItem?.cancel()
            }
            .enableInjection()
    }
}

private struct ScrollOffsetObserver: UIViewRepresentable {
    var onChange: (CGFloat) -> Void

    func makeUIView(context: Context) -> ObserverHostView {
        let view = ObserverHostView()
        view.onChange = onChange
        return view
    }

    func updateUIView(_ uiView: ObserverHostView, context: Context) {
        uiView.onChange = onChange
        uiView.attachIfNeeded()
    }
}

private final class ObserverHostView: UIView {
    var onChange: ((CGFloat) -> Void)?
    private var observations: [NSKeyValueObservation] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isUserInteractionEnabled = false
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        attachIfNeeded()
    }

    func attachIfNeeded() {
        guard observations.isEmpty else { return }

        guard let scrollView = nearestScrollView() ?? bestScrollViewInRoot() else { return }

        let topInset = scrollView.adjustedContentInset.top

        observations = [
            scrollView.observe(\.contentOffset, options: [.initial, .new]) { [weak self] _, change in
                let offsetY = (change.newValue?.y ?? 0) + topInset
                // Defer callback to avoid mutating SwiftUI state during an active view update pass.
                DispatchQueue.main.async { [weak self] in
                    self?.onChange?(offsetY)
                }
            }
        ]
    }

    private func nearestScrollView() -> UIScrollView? {
        var current = superview
        while let view = current {
            if let scrollView = view as? UIScrollView {
                return scrollView
            }
            current = view.superview
        }
        return nil
    }

    private func bestScrollViewInRoot() -> UIScrollView? {
        var root: UIView? = self
        while let parent = root?.superview {
            root = parent
        }

        guard let root else { return nil }

        let allScrollViews = findScrollViews(in: root)
        guard !allScrollViews.isEmpty else { return nil }

        let vertical = allScrollViews.filter {
            $0.alwaysBounceVertical || ($0.contentSize.height - $0.bounds.height) > 1
        }

        if let preferred = vertical.max(by: { $0.bounds.height < $1.bounds.height }) {
            return preferred
        }

        return allScrollViews.max(by: { $0.bounds.height < $1.bounds.height })
    }

    private func findScrollViews(in root: UIView) -> [UIScrollView] {
        var result: [UIScrollView] = []

        func walk(_ view: UIView) {
            if let scroll = view as? UIScrollView {
                result.append(scroll)
            }
            for subview in view.subviews {
                walk(subview)
            }
        }

        walk(root)
        return result
    }

    deinit {
        observations.forEach { $0.invalidate() }
    }
}
#else
struct ScrollGeometryReader {
    var contentOffset: CGPoint
    var contentInsets: EdgeInsets
}

struct ScrollOffsetChangeModifier<Value: Equatable>: ViewModifier {
    let transform: (ScrollGeometryReader) -> Value
    let action: (Value, Value) -> Void

    #if DEBUG
    @ObserveInjection var forceRedraw
    #endif

    func body(content: Content) -> some View {
        content
        .enableInjection()
    }
}

struct ScrollPhaseUpdateModifier: ViewModifier {
    let action: (ScrollPhases, ScrollPhases) -> Void

    #if DEBUG
    @ObserveInjection var forceRedraw
    #endif

    func body(content: Content) -> some View {
        content
        .enableInjection()
    }
}
#endif
