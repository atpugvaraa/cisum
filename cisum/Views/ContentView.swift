//
//  ContentView.swift
//  cisum
//
//  Created by Aarav Gupta on 29/11/25.
//

import SwiftUI
import YouTubeSDK

struct ContentView: View {
    @Environment(PrefetchSettings.self) private var prefetchSettings
    @Environment(NetworkPathMonitor.self) private var networkMonitor
    @Environment(PlayerViewModel.self) private var playerViewModel
    @Environment(SearchViewModel.self) private var searchViewModel
    @Environment(\.router) private var router
    @Environment(\.youtube) private var youtube
    
    @State private var activeTab: TabItem = .home

    @State private var isScrollingDown = false
    @State private var storedOffset: CGFloat = 0
    @State var scrollPhase: ScrollPhases = .idle
    @State var tabBarVisibility: Visibility = .visible
    
    let hideThresholds: CGFloat = 200
    let showThresholds: CGFloat = -40
    
    var body: some View {
#if os(iOS)
        iOSTabView(
            selection: $activeTab,
            searchText: Bindable(searchViewModel).searchText
        ) {
            Tab("Home", systemImage: "house.fill", value: TabItem.home) {
                tabRoot(for: .home) {
                    HomeView()
                }
            }
            
            Tab("Discover", systemImage: "globe", value: TabItem.discover) {
                tabRoot(for: .discover) {
                    DiscoverView()
                }
            }
            
            Tab("Library", systemImage: "music.note.list", value: TabItem.library) {
                tabRoot(for: .library) {
                    LibraryView()
                }
            }
            
            Tab("Search", systemImage: "magnifyingglass", value: TabItem.search, role: .search) {
                tabRoot(for: .search) {
                    SearchView()
                }
            }
        } onSearchSubmit: {
            searchViewModel.performDebouncedSearch()
        }
        .tabbarBottomViewAccessory {
            DynamicPlayerIsland()
        }
        .tabbarVisibility(tabBarVisibility)
        .animation(.smooth(duration: 0.3), value: tabBarVisibility)
        .onAppear {
            router.selectedTab = activeTab
        }
        .onChange(of: activeTab) { _, newValue in
            router.selectedTab = newValue
            tabBarVisibility = .visible
        }
        .environment(playerViewModel)
        .environment(searchViewModel)
        .environment(prefetchSettings)
        .environment(networkMonitor)
#elseif os(macOS)
        SearchView()
            .environment(playerViewModel)
            .environment(searchViewModel)
#endif
    }
}

#Preview {
    ContentView()
        .environment(PlayerViewModel())
        .environment(SearchViewModel())
        .environment(PrefetchSettings.shared)
        .environment(NetworkPathMonitor.shared)
}

private extension ContentView {
    func tabRoot<Content: View>(for tab: TabItem, @ViewBuilder content: () -> Content) -> some View {
        NavigationStack(path: router.binding(for: tab)) {
            ScrollView {
                content()
                    .safeAreaPadding(.bottom, 140)
            }
            .onScrollOffsetChange { oldValue, newValue in
                let scrollingDown = oldValue < newValue
                
                if self.isScrollingDown != scrollingDown {
                    storedOffset = newValue - (tabBarVisibility == .hidden ? 60 : 0)
                    self.isScrollingDown = scrollingDown
                }
                
                let diff = newValue - storedOffset
                if scrollPhase == .interacting {
                    if diff > hideThresholds {
                        tabBarVisibility = .hidden
                    } else if diff < showThresholds {
                        tabBarVisibility = .visible
                    }
                }
            }
            .onScrollPhaseUpdate { oldPhase, newPhase in
                scrollPhase = newPhase
            }
            .ignoresSafeArea()
            .usingRouter()
        }
        .ignoresSafeArea()
    }
}
