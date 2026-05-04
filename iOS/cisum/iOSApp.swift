//
//  iOSApp.swift
//  cisum
//
//  Created by Aarav Gupta on 29/11/25.
//

import Core
import SwiftUI
import YouTubeSDK
import SwiftData

@main
struct iOSApp: App {
    @Environment(\.scenePhase) private var scenePhase
    
    private let youtube = YouTube.shared
    private let cisum = cisumModule()

    var body: some Scene {
        WindowGroup {
            cisum.rootView
                .persistentSystemOverlays(.hidden)
                .tint(cisum.playerAccentColor)
                .modelContainer(cisum.modelContainer)
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            cisum.handleScenePhaseChange(newPhase)
        }
    }
}
