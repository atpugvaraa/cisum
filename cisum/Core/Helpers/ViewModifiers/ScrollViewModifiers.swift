//
//  ScrollViewModifiers.swift
//  cisum
//
//  Created by Aarav Gupta on 15/03/26.
//

import SwiftUI

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
            if currentPhase == .decelerating || currentPhase == .interacting {
                transition(to: .idle)
            }
        }

        idleWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    #if DEBUG
    @ObserveInjection var forceRedraw
    #endif

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        idleWorkItem?.cancel()
                        transition(to: .interacting)
                    }
                    .onEnded { _ in
                        transition(to: .decelerating)
                        scheduleIdleTransition(after: 0.22)
                    }
            )
            .onDisappear {
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

    override func didMoveToWindow() {
        super.didMoveToWindow()
        attachIfNeeded()
    }

    func attachIfNeeded() {
        guard observations.isEmpty else { return }

        var root: UIView? = self
        while let parent = root?.superview {
            root = parent
        }

        guard let searchRoot = root else { return }
        let scrollViews = findScrollViews(in: searchRoot)
        guard !scrollViews.isEmpty else { return }

        observations = scrollViews.map { scrollView in
            scrollView.observe(\.contentOffset, options: [.initial, .new]) { [weak self] scroll, _ in
                self?.onChange?(scroll.contentOffset.y + scroll.adjustedContentInset.top)
            }
        }
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
