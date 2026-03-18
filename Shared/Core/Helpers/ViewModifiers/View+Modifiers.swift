//
//  View+Modifiers.swift
//  cisum
//
//  Created by Aarav Gupta on 15/03/26.
//

import SwiftUI

extension View {
    func tabbarBottomViewAccessory<Content: View>(content: () -> Content) -> some View {
        self.environment(\.tabBarBottomAccessory, AnyView(content()))
    }

    func tabbarVisibility(_ visibility: Visibility) -> some View {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            return self
                .environment(\.tabBarVisibility, visibility)
                .toolbarVisibility(visibility, for: .tabBar)
        } else {
            return self.environment(\.tabBarVisibility, visibility)
        }
        #else
        return self.environment(\.tabBarVisibility, visibility)
        #endif
    }
}

extension View {
    func onScrollPhaseUpdate(
        action: @escaping (ScrollPhases, ScrollPhases) -> Void
    ) -> some View {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            return self.onScrollPhaseChange { oldPhase, newPhase in
                action(ScrollPhases(oldPhase), ScrollPhases(newPhase))
            }
        } else {
            return self.modifier(ScrollPhaseUpdateModifier(action: action))
        }
        #else
        return self
        #endif
    }

    func onScrollOffsetChange(
        action: @escaping (CGFloat, CGFloat) -> Void
    ) -> some View {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            return self.onScrollGeometryChange(
                for: CGFloat.self,
                of: { geo in
                    geo.contentOffset.y + geo.contentInsets.top
                },
                action: action
            )
        } else {
            return self.modifier(
                ScrollOffsetChangeModifier(
                    transform: { geometry in
                        geometry.contentOffset.y + geometry.contentInsets.top
                    },
                    action: action
                )
            )
        }
        #else
        return self
        #endif
    }
}
