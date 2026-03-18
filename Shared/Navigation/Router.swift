//
//  Router.swift
//  cisum
//
//  Created by Aarav Gupta on 14/03/26.
//

import SwiftUI

enum Routes: Hashable {
    case profile
    case settings
}

@Observable
final class Router {
    static let shared = Router()

    var selectedTab: TabItem = .home

    private var tabPaths: [TabItem: NavigationPath] = Dictionary(
        uniqueKeysWithValues: TabItem.allCases.map { ($0, NavigationPath()) }
    )

    func binding(for tab: TabItem) -> Binding<NavigationPath> {
        Binding(
            get: { self.tabPaths[tab] ?? NavigationPath() },
            set: { self.tabPaths[tab] = $0 }
        )
    }
    
    func navigate(to route: Routes) {
        updatePath(for: selectedTab) { path in
            path.append(route)
        }
    }
    
    func popToRoot() {
        updatePath(for: selectedTab) { path in
            path.removeLast(path.count)
        }
    }

    func pop() {
        updatePath(for: selectedTab) { path in
            guard !path.isEmpty else { return }
            path.removeLast()
        }
    }

    private func updatePath(for tab: TabItem, _ update: (inout NavigationPath) -> Void) {
        var path = tabPaths[tab] ?? NavigationPath()
        update(&path)
        tabPaths[tab] = path
    }
}
