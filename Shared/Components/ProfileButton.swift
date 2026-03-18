//
//  ProfileButton.swift
//  cisum
//
//  Created by Aarav Gupta on 14/03/26.
//

import SwiftUI

struct ProfileButton: View {
    @Environment(\.router) private var router
    
    @State var isClicked: Bool = false
    @State private var isHovered: Bool = false
    @Namespace private var namespace

    private enum Layout {
        static let collapsedSize: CGFloat = 60
        static let expandedWidth: CGFloat = 175
        static let expandedHeight: CGFloat = 195
        static let expandedProfileSize: CGFloat = 60
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

    var body: some View {
        if #available(macOS 26.0, iOS 26.0, *) {
            ZStack(alignment: .topTrailing) {
                if !isClicked {
                    collapsedGlass
                } else {
                    expandedGlass
                }
            }
            .padding()
            .onTapGesture {
                withAnimation(toggleAnimation) {
                    isClicked.toggle()
                }
            }

#if os(macOS)
            .onHover { hovering in
                guard hovering != isHovered else { return }
                withAnimation(hoverAnimation) {
                    isHovered = hovering
                }
            }
            .scaleEffect(isHovered ? Layout.hoverScale : 1, anchor: .topTrailing)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

#else
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
#endif
        } else {
            ZStack(alignment: .topTrailing) {
                if !isClicked {
                    fallbackCollapsedGlass
                } else {
                    fallbackExpandedGlass
                }
            }
            .padding()
            .onTapGesture {
                withAnimation(toggleAnimation) {
                    isClicked.toggle()
                }
            }
#if os(macOS)
            .onHover { hovering in
                guard hovering != isHovered else { return }
                withAnimation(hoverAnimation) {
                    isHovered = hovering
                }
            }
            .scaleEffect(isHovered ? Layout.hoverScale : 1, anchor: .topTrailing)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
#else
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
#endif
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

            Circle()
                .fill(.white.opacity(0.1))
                .padding(5)
                .matchedGeometryEffect(id: "PROFILE", in: namespace)
        }
    }

    private var expandedOverlayContent: some View {
        VStack {
            HStack {
                #if os(iOS)
                Button {
                    router.navigate(to: .profile)
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
                
                Circle()
                    .fill(.white.opacity(0.1))
                    .frame(width: Layout.expandedProfileSize, height: Layout.expandedProfileSize)
                    .matchedGeometryEffect(id: "PROFILE", in: namespace)
                #elseif os(macOS)
                Circle()
                    .fill(.white.opacity(0.1))
                    .frame(width: Layout.expandedProfileSize, height: Layout.expandedProfileSize)
                    .matchedGeometryEffect(id: "PROFILE", in: namespace)
                
                Button {
                    
                } label: {
                    if #available(macOS 26.0, *) {
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
                #endif
            }
            .padding([.top, .horizontal], 10)

            VStack {
                if #available(macOS 26.0, iOS 26.0, *) {
                    Button {
                        
                    } label: {
                        menuRowGlassModern
                            .overlay {
                                Text("Recents")
                            }
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        router.navigate(to: .settings)
                    } label: {
                        menuRowGlassModern
                            .overlay {
                                Text("Settings")
                            }
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        
                    } label: {
                        menuRowGlassFallback
                            .overlay {
                                Text("Recents")
                            }
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        router.navigate(to: .settings)
                    } label: {
                        menuRowGlassFallback
                            .overlay {
                                Text("Settings")
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
            .glassEffect(.regular)
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
    ProfileButton()
        .preferredColorScheme(.dark)
}
