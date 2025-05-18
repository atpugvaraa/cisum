//
//  Navigation.swift
//  cisum
//
//  Created by Aarav Gupta (github.com/atpugvaraa) on 17/03/25.
//

import SwiftUI

struct Navigation: View {
    @Environment(\.colorScheme) private var colorScheme
    
    @Binding var homePath: NavigationPath
    @Binding var discoverPath: NavigationPath
    @Binding var libraryPath: NavigationPath
    @Binding var searchPath: NavigationPath
    @Binding var tabbarHeight: CGFloat
    @Binding var selectedTab: Int
    
    @State private var showMiniPlayer: Bool = false
    
    private func setNavigationPath(for tab: SelectedTab) -> Binding<NavigationPath> {
        switch tab {
        case .home: return $homePath
        case .discover: return $discoverPath
        case .library: return $libraryPath
        case .search: return $searchPath
        }
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(SelectedTab.allCases, id: \.rawValue) { tab in
                TabContentView(
                    selectedPath: setNavigationPath(for: tab),
                    tabbarHeight: $tabbarHeight,
                    selectedTab: tab
                )
                .tabItem {
                    TabLabel(tab: tab)
                }
                .tag(tab.rawValue)
            }
        }
        .universalOverlay(show: $showMiniPlayer) {
            ExpandablePlayer(show: $showMiniPlayer)
                .ignoresSafeArea(.keyboard)
        }
        .onAppear {
            showMiniPlayer = true
            configureTabBarAppearance()
        }
    }
    
    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}
