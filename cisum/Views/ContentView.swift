//
//  ContentView.swift
//  cisum
//
//  Created by Aarav Gupta on 29/11/25.
//

import SwiftUI
import YouTubeSDK

struct ContentView: View {
    @Environment(\.youtube) private var youtube
    @Environment(PlayerViewModel.self) private var playerViewModel
    @Environment(SearchViewModel.self) private var searchViewModel
    @Environment(PrefetchSettings.self) private var prefetchSettings
    @Environment(NetworkPathMonitor.self) private var networkMonitor
    
    @State private var activeTab: TabItem = .home
    
    var body: some View {
#if os(iOS)
        iOSTabView(selection: $activeTab, searchText: Bindable(searchViewModel).searchText) {
            Tab("Home", systemImage: "house.fill", value: TabItem.home) {
                HomeView()
            }
            
            Tab("Discover", systemImage: "globe", value: TabItem.discover) {
                DiscoverView()
            }
            
            Tab("Library", systemImage: "music.note.list", value: TabItem.library) {
                LibraryView()
            }
            
            Tab("Search", systemImage: "magnifyingglass", value: TabItem.search, role: .search) {
                SearchView()
            }
        } onSearchSubmit: {
            searchViewModel.performDebouncedSearch()
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
