//
//  TabbarBackground.swift
//  cisum
//
//  Created by Aarav Gupta (github.com/atpugvaraa) on 29/12/24.
//

import SwiftUI

struct TabbarBackground: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    
    @Binding var tabbarHeight: CGFloat
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Rectangle().fill(.background).opacity(colorScheme == .dark ? 0.8 : 0.7)
                    .ignoresSafeArea()
                    .frame(height: max(MiniplayerHeight(h: horizontalSizeClass, v: verticalSizeClass).height, 0))
                    .mask(LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom))
                Rectangle().fill(.background).opacity(colorScheme == .dark ? 0.8 : 0.7)
                    .ignoresSafeArea()
                    .frame(height: max(tabbarHeight, 0))
                    
            }
            TabBarVariableBlurView()
                .ignoresSafeArea()
                .frame(height: max(tabbarHeight + MiniplayerHeight(h: horizontalSizeClass, v: verticalSizeClass).height, 0))
        }
    }
}

struct MiniplayerHeight {
    var h: UserInterfaceSizeClass?
    var v: UserInterfaceSizeClass?
    
    var height: CGFloat {
        // Implement your sizing logic
        return 55
    }
}
