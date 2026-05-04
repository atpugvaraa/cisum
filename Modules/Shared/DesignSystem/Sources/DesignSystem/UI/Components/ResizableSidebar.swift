//
//  ResizableSidebar.swift
//  cisum
//
//  Created by Aarav Gupta on 13/04/26.
//

import SwiftUI

#if os(macOS)
    import AppKit
#endif

struct ResizableSidebar<Sidebar: View, Content: View, Miniplayer: View>: View {
    @Binding var sidebarState: SidebarState
    @Binding var expandedWidth: CGFloat

    let collapsedWidth: CGFloat
    let minExpandedWidth: CGFloat
    let maxExpandedWidth: CGFloat
    let sidebarPadding: CGFloat

    let sidebarContent: (_ presentationState: SidebarState, _ width: CGFloat) -> Sidebar
    var mainContent: (_ leadingInset: CGFloat) -> Content
    var dynamicIslandPlayer: () -> Miniplayer

    @State private var isHoveringCollapsedSidebar = false
    @State private var isHoveringResizeHandle = false
    @State private var hasActiveResizeCursor = false
    @GestureState private var resizeTranslation: CGFloat = 0

    init(
        sidebarState: Binding<SidebarState>,
        expandedWidth: Binding<CGFloat>,
        collapsedWidth: CGFloat = 60,
        minExpandedWidth: CGFloat = 180,
        maxExpandedWidth: CGFloat = 360,
        sidebarPadding: CGFloat = 6,
        @ViewBuilder sidebarContent:
            @escaping (_ presentationState: SidebarState, _ width: CGFloat) -> Sidebar,
        @ViewBuilder mainContent: @escaping (_ leadingInset: CGFloat) -> Content,
        @ViewBuilder dynamicIslandPlayer: @escaping () -> Miniplayer
    ) {
        _sidebarState = sidebarState
        _expandedWidth = expandedWidth
        self.collapsedWidth = collapsedWidth
        self.minExpandedWidth = minExpandedWidth
        self.maxExpandedWidth = maxExpandedWidth
        self.sidebarPadding = sidebarPadding
        self.sidebarContent = sidebarContent
        self.mainContent = mainContent
        self.dynamicIslandPlayer = dynamicIslandPlayer
    }

    var body: some View {
        mainContent(leadingInset)
            .overlay(alignment: .leading) {
                sidebar
            }
            .overlay(alignment: .topTrailing) {
                miniplayer
            }
            .onChange(of: sidebarState) { _, newState in
                if newState == .expanded && isHoveringCollapsedSidebar {
                    isHoveringCollapsedSidebar = false
                }
            }

    }
}

extension ResizableSidebar {
    fileprivate var resizeHandleWidth: CGFloat {
        14
    }

    fileprivate var isTemporarilyExpandedFromHover: Bool {
        sidebarState == .collapsed && isHoveringCollapsedSidebar
    }

    fileprivate var isShowingExpandedPresentation: Bool {
        sidebarState == .expanded || isTemporarilyExpandedFromHover
    }

    fileprivate var presentationState: SidebarState {
        isShowingExpandedPresentation ? .expanded : .collapsed
    }

    fileprivate var clampedExpandedWidth: CGFloat {
        clamp(expandedWidth + resizeTranslation)
    }

    fileprivate var displayedWidth: CGFloat {
        isShowingExpandedPresentation ? clampedExpandedWidth : collapsedWidth
    }

    fileprivate var leadingInset: CGFloat {
        let resizeAllowance = (resizeHandleWidth / 2)
        return displayedWidth + sidebarPadding + resizeAllowance + 2
    }

    fileprivate var sidebar: some View {
        sidebarContent(presentationState, displayedWidth)
            .frame(width: displayedWidth)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .onHover { hovering in
                guard sidebarState == .collapsed else { return }
                withAnimation(.bouncy(duration: 0.3)) {
                    isHoveringCollapsedSidebar = hovering
                }
            }
            .overlay(alignment: .trailing) {
                if sidebarState == .expanded {
                    resizeHandle
                        .offset(x: resizeHandleWidth / 2)
                }
            }
            .padding(sidebarPadding)
            .animation(.snappy(duration: 0.28), value: isShowingExpandedPresentation)
            .animation(.snappy(duration: 0.22), value: displayedWidth)
    }

    fileprivate var miniplayer: some View {
        dynamicIslandPlayer()
    }

    fileprivate var resizeHandle: some View {
        ZStack {
            Rectangle()
                .fill(.clear)
                .frame(width: resizeHandleWidth)

            Rectangle()
                .fill(.white.opacity(isHoveringResizeHandle ? 0.32 : 0.16))
                .frame(width: isHoveringResizeHandle ? 2.5 : 1.5)
                .padding(.vertical, 8)
        }
        .frame(width: resizeHandleWidth)
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .onHover { hovering in
            updateResizeCursor(hovering: hovering)
        }
        .onDisappear {
            resetResizeCursorIfNeeded()
        }
        .gesture(resizeGesture)
    }

    fileprivate var resizeGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($resizeTranslation) { value, state, _ in
                guard sidebarState == .expanded else { return }
                state = value.translation.width
            }
            .onEnded { value in
                guard sidebarState == .expanded else { return }
                expandedWidth = clamp(expandedWidth + value.translation.width)
            }
    }

    fileprivate func clamp(_ proposedWidth: CGFloat) -> CGFloat {
        min(max(proposedWidth, minExpandedWidth), maxExpandedWidth)
    }

    fileprivate func updateResizeCursor(hovering: Bool) {
        guard hovering != isHoveringResizeHandle else { return }
        isHoveringResizeHandle = hovering

        #if os(macOS)
            if hovering {
                NSCursor.resizeLeftRight.push()
                hasActiveResizeCursor = true
            } else {
                resetResizeCursorIfNeeded()
            }
        #endif
    }

    fileprivate func resetResizeCursorIfNeeded() {
        #if os(macOS)
            guard hasActiveResizeCursor else { return }
            NSCursor.pop()
            hasActiveResizeCursor = false
        #endif
    }
}
