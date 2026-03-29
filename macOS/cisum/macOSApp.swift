//
//  macOSApp.swift
//  cisum
//
//  Created by Aarav Gupta on 18/03/26.
//

import SwiftUI
import YouTubeSDK
import SwiftData

@main
struct macOSApp: App {
    @Environment(\.scenePhase) private var scenePhase
    
    private let youtube = YouTube.shared
    private let router = Router.shared
    private let modelContainer: ModelContainer

    @State private var prefetchSettings: PrefetchSettings
    @State private var networkMonitor: NetworkPathMonitor
    @State private var playerViewModel: PlayerViewModel
    @State private var searchViewModel: SearchViewModel
    
    init() {
        let bootstrap = AppBootstrap.makeDependenciesOrFallback(youtube: YouTube.shared)
        self.modelContainer = bootstrap.modelContainer
        self.prefetchSettings = bootstrap.prefetchSettings
        self.networkMonitor = bootstrap.networkMonitor
        self.playerViewModel = bootstrap.playerViewModel
        self.searchViewModel = bootstrap.searchViewModel
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(modelContainer)
                .environment(\.youtube, youtube)
                .environment(\.router, router)
                .environment(prefetchSettings)
                .environment(playerViewModel)
                .environment(searchViewModel)
                .environment(networkMonitor)
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
        
        Settings {
            SettingsView()
                .environment(prefetchSettings)
                .environment(networkMonitor)
        }
    }
}

#if canImport(HotSwiftUI)
@_exported import HotSwiftUI
#elseif canImport(Inject)
@_exported import Inject
#else
// This code can be found in the Swift package:
// https://github.com/johnno1962/HotSwiftUI or
// https://github.com/krzysztofzablocki/Inject

#if DEBUG
import Combine

public class InjectionObserver: ObservableObject {
    public static let shared = InjectionObserver()
    @Published var injectionNumber = 0
    var cancellable: AnyCancellable? = nil
    let publisher = PassthroughSubject<Void, Never>()
    init() {
        cancellable = NotificationCenter.default.publisher(for:
            Notification.Name("INJECTION_BUNDLE_NOTIFICATION"))
            .sink { [weak self] change in
            self?.injectionNumber += 1
            self?.publisher.send()
        }
    }
}

extension SwiftUI.View {
    public func eraseToAnyView() -> some SwiftUI.View {
        return AnyView(self)
    }
    public func enableInjection() -> some SwiftUI.View {
        return eraseToAnyView()
    }
    public func onInjection(bumpState: @escaping () -> ()) -> some SwiftUI.View {
        return self
            .onReceive(InjectionObserver.shared.publisher, perform: bumpState)
            .eraseToAnyView()
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@propertyWrapper
public struct ObserveInjection: DynamicProperty {
    @ObservedObject private var iO = InjectionObserver.shared
    public init() {}
    public private(set) var wrappedValue: Int {
        get {0} set {}
    }
}
#else
extension SwiftUI.View {
    @inline(__always)
    public func eraseToAnyView() -> some SwiftUI.View { return self }
    @inline(__always)
    public func enableInjection() -> some SwiftUI.View { return self }
    @inline(__always)
    public func onInjection(bumpState: @escaping () -> ()) -> some SwiftUI.View {
        return self
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@propertyWrapper
public struct ObserveInjection {
    public init() {}
    public private(set) var wrappedValue: Int {
        get {0} set {}
    }
}
#endif
#endif
