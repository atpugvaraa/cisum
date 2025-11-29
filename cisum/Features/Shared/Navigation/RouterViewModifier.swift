//
//  RouterViewModifier.swift
//  cisum
//
//  Created by Aarav Gupta on 15/03/26.
//

import SwiftUI

struct RouterViewModifier: ViewModifier {
    @State private var router = Router.shared
    @State private var prefetchSettings = PrefetchSettings.shared
    @State private var networkMonitor = NetworkPathMonitor.shared
    
    private func routeView(to route: Routes) -> some View {
        Group {
            switch route {
            case .home:
                HomeView()
            case .discover:
                DiscoverView()
            case .library:
                LibraryView()
            case .search:
                SearchView()
            case .profile:
                ProfileView()
            case .settings:
                SettingsView()
                    .environment(prefetchSettings)
                    .environment(networkMonitor)
            }
        }
        .environment(router)
    }

    #if DEBUG
    @ObserveInjection var forceRedraw
    #endif

    func body(content: Content) -> some View {
        NavigationStack(path: $router.path) {
            content
                .environment(router)
                .navigationDestination(for: Routes.self) { newRoute in
                    routeView(to: newRoute)
                }
        }
        .enableInjection()
    }
}

extension View {
    func usingRouter() -> some View {
        modifier(RouterViewModifier())
    }
}
