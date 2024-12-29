//
//  TabbarBackground.swift
//  cisum
//
//  Created by Aarav Gupta on 29/12/24.
//

import SwiftUI

struct MiniplayerHeight {
    var h: UserInterfaceSizeClass?
    var v: UserInterfaceSizeClass?
    
    var height: CGFloat {
        // Implement your sizing logic
        return 55
    }
}

struct TabbarBackground: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Binding var tabbarHeight: CGFloat
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Rectangle().fill(.background)
                    .opacity(0.8)
                    .ignoresSafeArea()
                    .frame(height: max(MiniplayerHeight(h: horizontalSizeClass, v: verticalSizeClass).height, 0))
                    .mask(LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom))
                
                Rectangle().fill(.background)
                    .opacity(0.8)
                    .ignoresSafeArea()
                    .frame(height: max(tabbarHeight, 0))
            }
            
            VariableBlurView()
                .ignoresSafeArea()
                .frame(height: max(tabbarHeight + MiniplayerHeight(h: horizontalSizeClass, v: verticalSizeClass).height, 0))
        }
    }
}
