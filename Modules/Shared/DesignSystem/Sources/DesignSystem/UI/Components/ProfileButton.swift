//
//  ProfileButton.swift
//  cisum
//
//  Created by Aarav Gupta on 14/03/26.
//

import Kingfisher
import SwiftUI

public enum ProfileMenuAction {
    case profile
    case settings
    case plugins
    case home
    case library
    case recents
}

public struct ProfileButton: View {
    public var profileImageURL: URL?
    public var onAction: (ProfileMenuAction) -> Void

    public init(profileImageURL: URL? = nil, onAction: @escaping (ProfileMenuAction) -> Void) {
        self.profileImageURL = profileImageURL
        self.onAction = onAction
    }
    
    #if os(iOS)
    @State var isClicked: Bool = false
    #elseif os(macOS)
    @State var isClicked: Bool = true
    #endif
    @State private var isHovering: Bool = false
    @Namespace private var namespace

    private enum Layout {
        static let collapsedSize: CGFloat = 60
        static let expandedWidth: CGFloat = 175
        static let expandedHeight: CGFloat = 420
        static let expandedProfileSize: CGFloat = 50
        static let menuCornerRadius: CGFloat = 50
        static let menuHeight: CGFloat = 50
        static let hoverScale: CGFloat = 1.01
    }

    private var expandedShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 40,
            bottomLeadingRadius: 35,
            bottomTrailingRadius: 35,
            topTrailingRadius: 40,
            style: .continuous
        )
    }

    private var toggleAnimation: Animation {
        #if os(iOS)
            return .bouncy(duration: 0.3)
        #else
            return .smooth(duration: 0.32)
        #endif
    }

    private var hoverAnimation: Animation {
        .smooth(duration: 0.2)
    }

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            #if os(iOS)
                if isClicked {
                    Color.clear
                        .contentShape(Rectangle())
                        .ignoresSafeArea()
                        .onTapGesture {
                            closeMenu()
                        }
                }
            #endif
            menuSurface
                .onTapGesture {
                    toggleMenu()
                }
        }
        #if os(macOS)
            .onHover { isHovering in
                withAnimation(hoverAnimation) {
                    self.isHovering = isHovering
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        #else
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        #endif
        .onDisappear {
            isClicked = false
            isHovering = false
        }

    }

    @ViewBuilder
    private var menuSurface: some View {
        if #available(macOS 26.0, iOS 26.0, *) {
            if isExpanded {
                expandedGlass
            } else {
                collapsedGlass
            }
        } else {
            if isExpanded {
                fallbackExpandedGlass
            } else {
                fallbackCollapsedGlass
            }
        }
    }

    private var isExpanded: Bool {
        #if os(iOS)
            isClicked
        #else
            isClicked && isHovering
        #endif
    }

    private func toggleMenu() {
        withAnimation(toggleAnimation) {
            isClicked.toggle()
        }
    }

    private func closeMenu() {
        guard isClicked else { return }
        withAnimation(toggleAnimation) {
            isClicked = false
        }
    }

    private var collapsedOverlayContent: some View {
        ZStack {
            Color.clear
                .matchedGeometryEffect(id: "USERNAME", in: namespace)
                .frame(width: 1, height: 1)
                .offset(x: -10)

            Color.clear
                .matchedGeometryEffect(id: "PROFILE_BUTTONS", in: namespace)
                .frame(width: 1, height: 1)
                .offset(y: 80)

            if let url = profileImageURL {
                KFImage(url)
                    .placeholder {
                        Circle()
                            .fill(.white.opacity(0.1))
                    }
                    .matchedGeometryEffect(id: "PROFILE", in: namespace)
                    .clipShape(.circle)
                    .frame(width: Layout.collapsedSize, height: Layout.collapsedSize)
                    .padding(5)
            } else {
                Circle()
                    .fill(.white.opacity(0.1))
                    .padding(5)
                    .matchedGeometryEffect(id: "PROFILE", in: namespace)
            }
        }
    }

    private var expandedOverlayContent: some View {
        VStack {
            HStack {
                #if os(iOS)
                    Button {
                        onAction(.profile)
                    } label: {
                        if #available(iOS 26.0, *) {
                            RoundedRectangle(cornerRadius: 50)
                                .fill(.clear)
                                .glassEffect(.regular)
                                .overlay {
                                    Text("Profile")
                                        .fixedSize(horizontal: true, vertical: true)
                                }
                        } else {
                            // Fallback on earlier versions
                            RoundedRectangle(cornerRadius: Layout.menuCornerRadius)
                                .stroke(.white.opacity(0.1), lineWidth: 1.5)
                                .foregroundStyle(.ultraThinMaterial)
                                .overlay {
                                    Text("Profile")
                                        .fixedSize(horizontal: true, vertical: true)
                                }
                        }
                    }
                    .buttonStyle(.plain)
                    .matchedGeometryEffect(id: "USERNAME", in: namespace, anchor: .topTrailing)
                    .frame(maxWidth: .infinity)
                    .frame(height: Layout.expandedProfileSize)

                    if let url = profileImageURL {
                        KFImage(url)
                            .placeholder {
                                Circle()
                                    .fill(.white.opacity(0.1))
                            }
                            .matchedGeometryEffect(id: "PROFILE", in: namespace)
                            .clipShape(.circle)
                            .frame(
                                width: Layout.expandedProfileSize,
                                height: Layout.expandedProfileSize)
                    } else {
                        Circle()
                            .fill(.white.opacity(0.1))
                            .matchedGeometryEffect(id: "PROFILE", in: namespace)
                            .frame(
                                width: Layout.expandedProfileSize,
                                height: Layout.expandedProfileSize)
                    }

                #elseif os(macOS)
                    if let url = profileImageURL {
                        KFImage(url)
                            .placeholder {
                                Circle()
                                    .fill(.white.opacity(0.1))
                            }
                            .matchedGeometryEffect(id: "PROFILE", in: namespace)
                            .frame(width: Layout.collapsedSize, height: Layout.collapsedSize)
                    } else {
                        Circle()
                            .fill(.white.opacity(0.1))
                            .matchedGeometryEffect(id: "PROFILE", in: namespace)
                            .frame(width: Layout.collapsedSize, height: Layout.collapsedSize)
                    }

                    Spacer()
                #endif
            }
            .padding([.top, .horizontal], 10)

            VStack {
                if #available(macOS 26.0, iOS 26.0, *) {
                    #if os(macOS)
                        Button {
                            onAction(.profile)
                        } label: {
                            RoundedRectangle(cornerRadius: 50)
                                .fill(.clear)
                                .glassEffect(.regular, in: .rect(cornerRadius: Layout.menuCornerRadius))
                                .contentShape(.rect(cornerRadius: Layout.menuCornerRadius))
                                .padding(.horizontal, 10)
                                .frame(height: Layout.menuHeight)
                                .overlay {
                                    Text("Profile")
                                        .fixedSize(horizontal: true, vertical: true)
                                }
                        }
                        .buttonStyle(.plain)
                        .matchedGeometryEffect(id: "USERNAME", in: namespace, anchor: .topTrailing)
                    #endif

                    Button {
                        onAction(.home)
                    } label: {
                        menuRowGlassModern
                            .overlay {
                                Text("Home")
                            }
                    }
                    .buttonStyle(.plain)

                    Button {
                        onAction(.library)
                    } label: {
                        menuRowGlassModern
                            .overlay {
                                Text("Library")
                            }
                    }
                    .buttonStyle(.plain)

                    Button {
                        onAction(.recents)
                    } label: {
                        menuRowGlassModern
                            .overlay {
                                Text("Recents")
                            }
                    }
                    .buttonStyle(.plain)

                    Button {
                        onAction(.settings)
                    } label: {
                        menuRowGlassModern
                            .overlay {
                                Text("Settings")
                            }
                    }
                    .buttonStyle(.plain)

                    Button {
                        onAction(.plugins)
                    } label: {
                        menuRowGlassModern
                            .overlay {
                                Text("Plugins")
                            }
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        onAction(.recents)
                    } label: {
                        menuRowGlassFallback
                            .overlay {
                                Text("Recents")
                            }
                    }
                    .buttonStyle(.plain)

                    Button {
                        onAction(.settings)
                    } label: {
                        menuRowGlassFallback
                            .overlay {
                                Text("Settings")
                            }
                    }
                    .buttonStyle(.plain)

                    Button {
                        onAction(.plugins)
                    } label: {
                        menuRowGlassFallback
                            .overlay {
                                Text("Plugins")
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .matchedGeometryEffect(id: "PROFILE_BUTTONS", in: namespace)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @available(macOS 26.0, iOS 26.0, *)
    private var collapsedGlass: some View {
        Circle()
            .glassEffect(.regular, in: .circle)
            .matchedGeometryEffect(id: "GLASS", in: namespace)
            .frame(width: Layout.collapsedSize, height: Layout.collapsedSize)
            .overlay { collapsedOverlayContent }
    }

    @available(macOS 26.0, iOS 26.0, *)
    private var expandedGlass: some View {
        expandedShape
            .glassEffect(.regular, in: expandedShape)
            .matchedGeometryEffect(id: "GLASS", in: namespace)
            .frame(width: Layout.expandedWidth, height: Layout.expandedHeight)
            .overlay { expandedOverlayContent }
    }

    private var fallbackCollapsedGlass: some View {
        Circle()
            .stroke(.white.opacity(0.2), lineWidth: 2)
            .fill(.ultraThinMaterial)
            .matchedGeometryEffect(id: "GLASS", in: namespace)
            .frame(width: Layout.collapsedSize, height: Layout.collapsedSize)
            .overlay { collapsedOverlayContent }
    }

    private var fallbackExpandedGlass: some View {
        expandedShape
            .stroke(.white.opacity(0.2), lineWidth: 3)
            .fill(.ultraThinMaterial)
            .matchedGeometryEffect(id: "GLASS", in: namespace)
            .frame(width: Layout.expandedWidth, height: Layout.expandedHeight)
            .overlay { expandedOverlayContent }
    }

    @available(macOS 26.0, iOS 26.0, *)
    private var menuRowGlassModern: some View {
        RoundedRectangle(cornerRadius: Layout.menuCornerRadius)
            .fill(.clear)
            .glassEffect(.regular, in: .rect(cornerRadius: Layout.menuCornerRadius))
            .contentShape(.rect(cornerRadius: Layout.menuCornerRadius))
            .padding(.horizontal, 10)
            .frame(height: Layout.menuHeight)
    }

    private var menuRowGlassFallback: some View {
        RoundedRectangle(cornerRadius: Layout.menuCornerRadius)
            .stroke(.white.opacity(0.1), lineWidth: 1.5)
            .foregroundStyle(.ultraThinMaterial)
            .padding(.horizontal, 10)
            .frame(height: Layout.menuHeight)
    }
}

#Preview {
    ProfileButton(profileImageURL: nil, onAction: { _ in })
        .preferredColorScheme(.dark)
}
