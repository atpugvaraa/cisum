//
//  macOSApp.swift
//  cisum
//
//  Created by Aarav Gupta on 18/03/26.
//

import Core
import SwiftUI
import YouTubeSDK
import SwiftData
import Services
import Utilities

@main
struct macOSApp: App {
    @Environment(\.scenePhase) private var scenePhase
    
    private let youtube = YouTube.shared
    private let cisum = cisumModule()
    @State private var searchOverlay = SearchOverlayController()
    
    var body: some Scene {
        WindowGroup {
            cisum.rootView
                .environment(searchOverlay)
                .tint(cisum.playerAccentColor)
                .background {
                    backgroundFill
                }
                .clipShape(.rect(cornerRadius: 26, style: .continuous))
                .removeWindowDecorations()
                .modelContainer(cisum.modelContainer)
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            cisum.handleScenePhaseChange(newPhase)
        }
        
        Settings {
            cisum.settingsView
        }
    }

    @ViewBuilder
    private var backgroundFill: some View {
        if #available(macOS 26.0, *) {
            Rectangle()
                .glassEffect(.regular, in: .rect(cornerRadius: 26))
        } else {
            Rectangle()
                .fill(.ultraThinMaterial.opacity(0.9))
        }
    }
}

extension View {
    func removeWindowDecorations() -> some View {
        self
            .background(WindowModifier())
    }
}

struct WindowModifier: NSViewRepresentable {
    func makeNSView(context: Context) -> some NSView {
        let view = NSView()
        
        Task { @MainActor in
            configureWindow(for: view)
        }
        
        return view
    }
    
    func updateNSView(_ nsView: NSViewType, context: Context) {
        Task { @MainActor in
            configureWindow(for: nsView)
        }
    }

    private func configureWindow(for view: NSView) {
        guard let window = view.window else { return }

        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.titlebarSeparatorStyle = .none
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true

        window.backgroundColor = .clear
        window.styleMask = [.borderless, .resizable, .fullSizeContentView]
        window.isOpaque = false
        window.hasShadow = true
        window.isMovableByWindowBackground = false

        guard let contentView = window.contentView else { return }
        contentView.wantsLayer = true
        contentView.layer?.masksToBounds = true
        contentView.layer?.cornerCurve = .continuous
    }
}
