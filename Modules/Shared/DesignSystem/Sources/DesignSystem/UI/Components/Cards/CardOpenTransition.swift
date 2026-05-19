import SwiftUI

#if os(iOS)
import UIKit
#endif

public struct CardOpenTransition<Hero: View, Content: View>: View {
    var config: TransitionConfig = .init()
    @ViewBuilder public var hero: (_ isCardExpanded: Bool, _ dismiss: (() -> ())?) -> Hero
    @ViewBuilder public var content: (_ safeArea: EdgeInsets, _ dismiss: @escaping () -> ()) -> Content
    @State private var showFullScreenCover: Bool = false
    @State private var sourceRect: CGRect = .zero
    @State private var buttonScale: CGFloat = 1
    
    public init(
        @ViewBuilder hero: @escaping (_ isCardExpanded: Bool, _ dismiss: (() -> ())?) -> Hero,
        @ViewBuilder content: @escaping (_ safeArea: EdgeInsets, _ dismiss: @escaping () -> ()) -> Content
    ) {
        self.hero = hero
        self.content = content
    }

    public var body: some View {
        Button {
            withoutAnimation {
                showFullScreenCover = true
            }
        } label: {
            Rectangle()
                .foregroundStyle(.clear)
                .overlay {
                    if !showFullScreenCover {
                        hero(false, nil)
                    }
                }
                .onGeometryChange(for: CGRect.self, of: { geo in
                    geo.frame(in: .global)
                }, action: { newValue in
                    buttonScale = newValue.width / sourceRect.width
                })
        }
        .buttonStyle(CardStyle())
        .onGeometryChange(for: CGRect.self, of: { geo in
            geo.frame(in: .global)
        }, action: { newValue in
            sourceRect = newValue
        })
        #if os(iOS)
        .fullScreenCover(isPresented: $showFullScreenCover) {
            TransitionFullScreenCover(
                config: config,
                buttonScale: $buttonScale,
                showFullScreenCover: $showFullScreenCover,
                sourceRect: $sourceRect,
                hero: hero,
                content: content
            )
        }
        #endif
    }
}

fileprivate struct TransitionFullScreenCover<Hero: View, Content: View>: View {
    var config: TransitionConfig
    @Binding var buttonScale: CGFloat
    @Binding var showFullScreenCover: Bool
    @Binding var sourceRect: CGRect
    @ViewBuilder var hero: (_ isCardExpanded: Bool, _ dismiss: (() -> ())?) -> Hero
    @ViewBuilder var content: (_ safeArea: EdgeInsets, _ dismiss: @escaping () -> ()) -> Content

    @State private var animateContents: Bool = false
    @State private var dragScale: CGFloat = 1
    @State private var safeArea: EdgeInsets = .init()

    #if os(iOS)
    @State private var isHorizontalSwipe: Bool = false
    #endif

    var body: some View {
        let cornerRadius = animateContents ? config.detailCornerRadius : config.cardCornerRadius

        ScrollView(.vertical) {
            VStack(spacing: 0) {
                Rectangle()
                    .foregroundStyle(.clear)
                    .overlay { hero(animateContents, dismiss) }
                    .frame(
                        width: animateContents ? nil : sourceRect.width,
                        height: animateContents ? config.detailCardHeight : sourceRect.height
                    )
                    .offset(
                        x: animateContents ? 0 : sourceRect.minX,
                        y: animateContents ? 0 : sourceRect.minY
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .visualEffect { [animateContents] content, proxy in
                        let minY = proxy.frame(in: .scrollView).minY
                        let height = animateContents ? (proxy.size.height + 10) : 0

                        return content
                            .offset(y: -minY > height ? -(minY + height) : 0)
                            .offset(y: minY > 0 ? -minY : 0)
                    }
                    .zIndex(1000)

                content(safeArea, dismiss)
            }
        }
        .background(.background)
        .mask(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: cornerRadius - 1, style: .circular)
                .frame(
                    width: animateContents ? nil : sourceRect.width,
                    height: animateContents ? nil : sourceRect.height
                )
                .offset(
                    x: animateContents ? 0 : sourceRect.minX,
                    y: animateContents ? 0 : sourceRect.minY
                )
        }
        .overlay(alignment: .topLeading) {
            DismissButton()
                .hidden()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .frame(
                    width: animateContents ? nil : sourceRect.width,
                    height: animateContents ? config.detailCardHeight : sourceRect.height
                )
                .offset(
                    x: animateContents ? 0 : sourceRect.minX,
                    y: animateContents ? safeArea.top : sourceRect.minY
                )
        }
        .scaleEffect(dragScale)
        .scaleEffect(buttonScale)
        .ignoresSafeArea()
        #if os(iOS)
        .gesture(
            CardGesture { gesture in
                handleGesture(gesture)
            }
        )
        #endif
        .onGeometryChange(for: EdgeInsets.self) { geo in
            geo.safeAreaInsets
        } action: { newValue in
            safeArea = newValue
        }
        .task {
            guard !animateContents else { return }

            withAnimation(config.animation) {
                animateContents = true
            }
        }
        .presentationBackground {
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(animateContents ? 1 : 0)
        }
    }

    @ViewBuilder
    private func DismissButton() -> some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .frame(width: 20, height: 30)
                .contentShape(.circle)
        }
        .cardGlassButtonStyle()
        .padding(.trailing, 15)
        .animation(.linear(duration: 0.15)) {
            $0.opacity(animateContents ? 1 : 0)
        }
        .opacity((dragScale - 0.95) / 0.05)
    }

    #if os(iOS)
    private func handleGesture(_ gesture: UIPanGestureRecognizer) {
        let state = gesture.state
        let translationX = gesture.translation(in: gesture.view).x * 1.2
        let translationY = gesture.translation(in: gesture.view).y
        let translation = isHorizontalSwipe ? translationX : translationY

        if state == .began {
            isHorizontalSwipe = gesture.location(in: gesture.view).x < 30
        }

        if state == .began || state == .changed {
            let progress = max(min(translation / config.detailCardHeight, 1), 0)
            dragScale = 1 - (progress * 0.2)
        } else {
            isHorizontalSwipe = false

            if dragScale < 0.9 {
                dismiss()
            } else {
                withAnimation(config.animation) {
                    dragScale = 1
                }
            }
        }
    }
    #endif

    private func dismiss() {
        withAnimation(config.animation, completionCriteria: .removed) {
            dragScale = 1
            animateContents = false
        } completion: {
            withoutAnimation {
                showFullScreenCover = false
            }
        }
    }
}

fileprivate extension View {
    func withoutAnimation(block: @escaping () -> ()) {
        DispatchQueue.main.async {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                block()
            }
        }
    }
}
