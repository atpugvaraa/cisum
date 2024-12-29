//
//  MainNavigation.swift
//  cisum
//
//  Created by Aarav Gupta on 29/12/24.
//

import SwiftUI

struct MainNavigation: View {
    @Binding var browsePath: NavigationPath
    @Binding var libraryPath: NavigationPath
    @Binding var searchPath: NavigationPath
    @Binding var profilePath: NavigationPath
    @Binding var tabbarHeight: CGFloat
    @Binding var selectedTab: Int
    
    private func setNavigationPath(for tab: SelectedTab) -> Binding<NavigationPath> {
        switch tab {
        case .browse: return $browsePath
        case .library: return $libraryPath
        case .search: return $searchPath
        case .profile: return $profilePath
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
    }
}
