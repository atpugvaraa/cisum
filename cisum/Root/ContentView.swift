//
//  ContentView.swift
//  cisum
//
//  Created by Aarav Gupta (github.com/atpugvaraa) on 29/12/24.
//

import SwiftUI

struct ContentView: View {
    @Environment(PlayerProperties.self) private var playerProperties
    @Environment(NavigationState.self) private var navigationState
    
    @State var tabbarHeight: CGFloat = 83
    
    var selectedTab: Binding<Int> { Binding(
        get: { navigationState.currentTab.rawValue },
        set: { navigationState.selectTab($0) }
    )}
    
    var body: some View {
        Navigation(
            homePath: navigationState.path(for: .home),
            discoverPath: navigationState.path(for: .discover),
            libraryPath: navigationState.path(for: .library),
            searchPath: navigationState.path(for: .search),
            tabbarHeight: $tabbarHeight,
            selectedTab: selectedTab
        )
        .environment(navigationState)
        .environment(playerProperties)
    }
}

#Preview {
    RootView {
        ContentView()
    }
}
