//
//  SidebarView.swift
//  cisum
//
//  Created by Aarav Gupta on 13/04/26.
//

import SwiftUI

#if os(macOS)
import AppKit
#endif

enum SidebarState {
    case collapsed
    case expanded
}

struct SidebarView: View {
    @Binding var sidebarState: SidebarState
    let presentationState: SidebarState
    let selectedTab: TabItem
    let onTabSelected: (TabItem) -> Void
    let onProfileTap: () -> Void

    var body: some View {
        Group {
            if #available(macOS 26.0, iOS 26.0, *) {
                Rectangle()
                    .fill(.clear)
                    .glassEffect(
                        .regular, in: .rect(cornerRadius: isExpandedPresentation ? 24 : 50)
                    )
            } else {
                RoundedRectangle(cornerRadius: 50)
                    .fill(.ultraThinMaterial)
            }
        }
        .allowWindowDrag()
        .overlay {
            sidebarControls
        }
        .animation(.easeInOut, value: presentationState)

    }
}

extension View {
    func allowWindowDrag() -> some View {
        self.modifier(SidebarDragModifier())
    }
}

#if os(macOS)
struct SidebarDragModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(SidebarDragRegionWrapper())
    }
}

struct SidebarDragRegionWrapper: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        SidebarDragRegionView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.window?.isMovableByWindowBackground = false
    }
}
#else
struct SidebarDragModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
    }
}
#endif

#if os(macOS)
private final class SidebarDragRegionView: NSView {
    private var dragTrackingArea: NSTrackingArea?

    override var mouseDownCanMoveWindow: Bool {
        true
    }

    override func viewDidMoveToWindow() {
        window?.isMovableByWindowBackground = false
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        window?.isMovableByWindowBackground = false
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let dragTrackingArea {
            removeTrackingArea(dragTrackingArea)
        }

        let area = NSTrackingArea(
            rect: .zero,
            options: [.inVisibleRect, .activeAlways, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        dragTrackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        window?.isMovableByWindowBackground = true
    }

    override func mouseExited(with event: NSEvent) {
        window?.isMovableByWindowBackground = false
    }
}
#endif

extension SidebarView {
    fileprivate var isExpandedPresentation: Bool {
        presentationState == .expanded
    }

    fileprivate var sidebarControls: some View {
        VStack(spacing: 12) {
            expandControl

            Divider()

            VStack(spacing: 8) {
                ForEach(TabItem.allCases, id: \.rawValue) { tab in
                    tabButton(for: tab)
                }
            }

            Spacer()

            Divider()

            profileButton
                .padding(.bottom, -6)
        }
        .padding(12)
    }

    fileprivate var expandControl: some View {
        Button {
            withAnimation(.bouncy(duration: 0.3)) {
                sidebarState = sidebarState == .expanded ? .collapsed : .expanded
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: sidebarState == .expanded ? "chevron.left" : "chevron.right")
                    .font(.system(size: 13, weight: .semibold))

                if isExpandedPresentation {
                    Text(sidebarState == .expanded ? "Collapse" : "Pin Open")
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .transition(.opacity)
                }
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: isExpandedPresentation ? .leading : .center)
            .frame(height: 36)
            .padding(.horizontal, isExpandedPresentation ? 13 : 0)
            .background {
                sidebarControlBackground(cornerRadius: 18)
            }
        }
        .buttonStyle(.plain)
    }

    fileprivate var profileButton: some View {
        Button {
            withAnimation(.bouncy(duration: 0.3)) {
                onProfileTap()
            }
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .frame(height: 36)

                if isExpandedPresentation {
                    Text("Aarav Gupta")
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .transition(.opacity)
                }
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: isExpandedPresentation ? .leading : .center)
            .frame(width: isExpandedPresentation ? nil : 48, height: 48)
            .padding(.horizontal, isExpandedPresentation ? 9 : 0)
            .background {
                sidebarControlBackground(cornerRadius: 50)
            }
        }
        .buttonStyle(.plain)
    }

    fileprivate func tabButton(for tab: TabItem) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) {
                onTabSelected(tab)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: tab.sidebarIcon)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 18)

                if isExpandedPresentation {
                    Text(tab.sidebarTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                        .transition(.opacity)
                }
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: isExpandedPresentation ? .leading : .center)
            .frame(height: 36)
            .padding(.horizontal, isExpandedPresentation ? 9 : 0)
            .background {
                if tab == selectedTab {
                    sidebarControlBackground(cornerRadius: 20)
                } else {
                    Color.clear
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    fileprivate func sidebarControlBackground(cornerRadius: CGFloat) -> some View {
        if #available(macOS 26.0, iOS 26.0, *) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.clear)
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
        }
    }
}

extension TabItem {
    fileprivate var sidebarTitle: String {
        switch self {
        case .home:
            return "Home"
        case .discover:
            return "Discover"
        case .library:
            return "Library"
        case .search:
            return "Search"
        }
    }

    fileprivate var sidebarIcon: String {
        switch self {
        case .home:
            return "house.fill"
        case .discover:
            return "globe"
        case .library:
            return "music.note.list"
        case .search:
            return "magnifyingglass"
        }
    }
}
