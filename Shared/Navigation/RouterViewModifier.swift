//
//  RouterViewModifier.swift
//  cisum
//
//  Created by Aarav Gupta on 15/03/26.
//

import SwiftUI

struct RouterViewModifier: ViewModifier {
    @State private var router = Router.shared
    
    private func routeView(to route: Routes) -> some View {
        Group {
            switch route {
            case .profile:
                ProfileView()
            case .settings:
                SettingsView()
            case .playlistDetail(let playlistID):
                PlaylistDetailView(playlistID: playlistID)
            }
        }
        .environment(\.router, router)
    }

    #if DEBUG
    @ObserveInjection var forceRedraw
    #endif

    func body(content: Content) -> some View {
        content
            .environment(\.router, router)
            .navigationDestination(for: Routes.self) { newRoute in
                routeView(to: newRoute)
            }
        .enableInjection()
    }
}

extension View {
    func usingRouter() -> some View {
        modifier(RouterViewModifier())
    }
}
