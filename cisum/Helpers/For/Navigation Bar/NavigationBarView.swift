//
//  NavigationBarView.swift
//  cisum
//
//  Created by Aarav Gupta (github.com/atpugvaraa) on 18/03/25.
//

import SwiftUI

struct NavigationBarView<Content: View>: View {
    @Environment(\.navigationBarStyle) private var config

    var title: String = ""
    var blurHeight: CGFloat
    var blurRadius: CGFloat
    var icon: String?
    var showTopRightButton: Bool
    var content: Content
    
    @Binding var scrollOffset: CGFloat
    
    init(title: String, blurRadius: CGFloat = 12, blurHeight: CGFloat = 50, scrollOffset: Binding<CGFloat>, icon: String? = nil,  @ViewBuilder content: () -> Content) {
        self.title = title
        self.blurRadius = blurRadius
        self.blurHeight = blurHeight
        self._scrollOffset = scrollOffset
        self.icon = icon
        self.showTopRightButton = icon != nil
        self.content = content()
    }
    
    var body: some View {
        GeometryReader { geo in
            Group {
                if config.styleType == .search {
                    content
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            Color.clear
                                .frame(height: 140)

                            ScrollOffsetBackground { offset in
                                self.scrollOffset = offset - geo.safeAreaInsets.top
                            }
                            .frame(height: 0)

                            content
                        }
                    }
                }
            }
            .variableBlur(radius: blurRadius, maskHeight: blurHeight, opacity: opacity)
            .ignoresSafeArea()
            .overlay {
                NavigationBar(scrollOffset: scrollOffset, title: title, icon: icon, showTopRightButton: showTopRightButton)
            }
        }
    }
    
    var opacity: CGFloat {
        let startOffset: CGFloat = 0
        let endOffset: CGFloat = 1
        let transitionOffset: CGFloat = 60
        let progress = min(max(scrollOffset / transitionOffset , 0), 1)
        
        return endOffset + (startOffset - endOffset) * progress
    }
}
