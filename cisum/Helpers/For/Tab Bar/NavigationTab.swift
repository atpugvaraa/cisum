//
//  Tab.swift
//  cisum
//
//  Created by Aarav Gupta (github.com/atpugvaraa) on 29/12/24.
//

import SwiftUI

struct TabContentView: View {
    let selectedPath: Binding<NavigationPath>
    let tabbarHeight: Binding<CGFloat>
    let selectedTab: SelectedTab
    
    @Environment(NavigationState.self) private var navigationState
    
    var body: some View {
        ZStack {
            content
            
            VStack {
                Spacer()
                TabbarBackground(tabbarHeight: tabbarHeight)
            }
            .ignoresSafeArea()
        }
        .toolbarBackground(.hidden, for: .tabBar)
        .onAppear {
            print("Tab appeared: \(selectedTab.title)")
        }
    }
    
    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .home:
            HomeTab(homePath: selectedPath)
        case .discover:
            DiscoverTab(discoverPath: selectedPath)
        case .library:
            LibraryTab(libraryPath: selectedPath)
        case .search:
            SearchTab(searchPath: selectedPath)
        }
    }
}
