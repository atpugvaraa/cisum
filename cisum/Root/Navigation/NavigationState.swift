//
//  NavigationState.swift
//  cisum
//
//  Created by Trae AI on 18/03/25.
//

import SwiftUI
import Combine

@Observable @MainActor
class NavigationState {
    var currentTab: SelectedTab = .home
    var previousTab: SelectedTab = .home
    var homePath = NavigationPath()
    var discoverPath = NavigationPath()
    var libraryPath = NavigationPath()
    var searchPath = NavigationPath()
    
    func resetPath(for tab: SelectedTab) {
        switch tab {
        case .home:
            homePath = NavigationPath()
        case .discover:
            discoverPath = NavigationPath()
        case .library:
            libraryPath = NavigationPath()
        case .search:
            searchPath = NavigationPath()
        }
    }
    
    func path(for tab: SelectedTab) -> Binding<NavigationPath> {
        switch tab {
        case .home: return Binding(get: { self.homePath }, set: { self.homePath = $0 })
        case .discover: return Binding(get: { self.discoverPath }, set: { self.discoverPath = $0 })
        case .library: return Binding(get: { self.libraryPath }, set: { self.libraryPath = $0 })
        case .search: return Binding(get: { self.searchPath }, set: { self.searchPath = $0 })
        }
    }
    
    func selectTab(_ tab: Int) {
        let newTab = SelectedTab(rawValue: tab) ?? .home
        previousTab = currentTab
        currentTab = newTab
        
        if previousTab == currentTab {
            resetPath(for: currentTab)
        }
    }
}
