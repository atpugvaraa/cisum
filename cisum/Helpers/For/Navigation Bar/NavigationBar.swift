//
//  NavigationBar.swift
//  cisum
//
//  Created by Aarav Gupta (github.com/atpugvaraa) on 18/03/25.
//

import SwiftUI

struct NavigationBar: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.navigationBarStyle) private var config
    
    var scrollOffset: CGFloat
    var title: String
    var icon: String?
    
    @State var showTopRightButton: Bool
    
    var body: some View {
        ZStack {
            Color.clear
                .frame(height: interpolation(start: 200, end: 130, transitionOffset: 60))
                .edgesIgnoringSafeArea(.top)
            
            VStack(spacing: 0) {
                header
                
                if config.showSearchBar {
                    searchBar
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
    
    var header: some View {
        HStack {
            Text(title)
                .font(.system(size: interpolation(start: 35, end: 30, transitionOffset: 60)))
                .fontWeight(.bold)
            
            Spacer()
            
            if showTopRightButton == true {
                topRightButton()
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.9, blendDuration: 0.3), value: scrollOffset)
        .offset(y: interpolation(start: -30, end: -40, transitionOffset: 60))
        .padding()
    }
    
    var searchBar: some View {
        #warning("Implementation for searchbar")
        return EmptyView()
    }
    
    @ViewBuilder func topRightButton() -> some View {
        NavigationLink {
            
        } label: {
            ZStack {
                Circle()
                    .fill(colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.2))
                
                Circle()
                    .stroke(lineWidth: 2)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.2))
                
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 25))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(colorScheme == .dark ? Color.white : Color.black)
                        .scaleEffect(interpolation(start: 1.0, end: 0.857, transitionOffset: 60))
                }
            }
            .frame(height: interpolation(start: 35, end: 30, transitionOffset: 60))
        }
    }
    
    private func interpolation(start: CGFloat, end: CGFloat, transitionOffset: CGFloat) -> CGFloat {
        let progress = min(max(scrollOffset / transitionOffset , 0), 1)
        return end + (start - end) * progress
    }
}
