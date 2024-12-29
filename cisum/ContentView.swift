//
//  ContentView.swift
//  cisum
//
//  Created by Aarav Gupta on 29/12/24.
//

import SwiftUI

struct ContentView: View {
    @State private var previousTab: SelectedTab = .browse
    @State private var currentTab: SelectedTab = .browse
    @State var browsePath = NavigationPath()
    @State var libraryPath = NavigationPath()
    @State var searchPath = NavigationPath()
    @State var profilePath = NavigationPath()
    @State var tabbarHeight: CGFloat = 83
    
    private func setNavigationPath(for tab: SelectedTab) {
        switch tab {
        case .browse:
            browsePath = NavigationPath()
        case .library:
            libraryPath = NavigationPath()
        case .search:
            searchPath = NavigationPath()
        case .profile:
            profilePath = NavigationPath()
        }
    }
    
    var selectedTab: Binding<Int> { Binding(
        get: {
            currentTab.rawValue
        },
        set: { newValue in
            previousTab = currentTab
            currentTab = SelectedTab(rawValue: newValue) ?? .browse

            if previousTab == currentTab {
                print("Pop to root for \(currentTab)")
                setNavigationPath(for: currentTab)
            }
        }
    )}
    
    var body: some View {
        MainNavigation(browsePath: $browsePath, libraryPath: $libraryPath, searchPath: $searchPath, profilePath: $profilePath, tabbarHeight: $tabbarHeight, selectedTab: selectedTab)
    }
}

#Preview {
    ContentView()
}
