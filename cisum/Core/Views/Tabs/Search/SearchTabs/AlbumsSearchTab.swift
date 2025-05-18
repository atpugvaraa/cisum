//
//  AlbumsSearchTab.swift
//  cisum
//
//  Created by Aarav Gupta on 18/05/25.
//

import SwiftUI

struct AlbumsSearchTab: View {
    @Binding var scrollOffset: CGFloat
    
    var body: some View {
        GeometryReader { geo in
            let safeArea = geo.safeAreaInsets
            
            ScrollView {
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: 160)

                    ScrollOffsetBackground { offset in
                        self.scrollOffset = offset - safeArea.top
                    }
                    .frame(height: 0)

                    content
                }
            }
        }
    }
    
    var content: some View {
        ForEach(0...10, id: \.self) { _ in
            VStack(spacing: 24) {
                Rectangle()
                    .fill(.blue)
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .padding()
            }
        }
    }
}
