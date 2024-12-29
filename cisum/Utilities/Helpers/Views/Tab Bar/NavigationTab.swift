//
//  Tab.swift
//  cisum
//
//  Created by Aarav Gupta on 29/12/24.
//

import SwiftUI

struct TabContentView: View {
    let selectedPath: Binding<NavigationPath>
    let tabbarHeight: Binding<CGFloat>
    let selectedTab: SelectedTab
    
    var body: some View {
        ZStack {
            contentView
            
            VStack {
                Spacer()
                TabbarBackground(tabbarHeight: tabbarHeight)
            }
            .ignoresSafeArea()
        }
        .toolbarBackground(.hidden, for: .tabBar)
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case .browse:
            BrowsePage(browsePath: selectedPath)
        case .library:
            LibraryPage(libraryPath: selectedPath)
        case .search:
            SearchPage(searchPath: selectedPath)
        case .profile:
            ProfilePage(profilePath: selectedPath)
        }
    }
}
