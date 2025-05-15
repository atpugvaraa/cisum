//
//  cisumApp.swift
//  cisum
//
//  Created by Aarav Gupta (github.com/atpugvaraa) on 29/12/24.
//

import SwiftUI

@main
struct cisumApp: App {
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var navigationState = NavigationState()
    @State private var playerProperties = PlayerProperties()
    
    var body: some Scene {
        WindowGroup {
            RootView {
                ContentView()
                    .environment(navigationState)
                    .environment(playerProperties)
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .active:
                print("App became active")
            case .inactive:
                print("App became inactive")
            case .background:
                print("App went to background")
            @unknown default:
                print("Unknown scene phase")
            }
        }
    }
}
