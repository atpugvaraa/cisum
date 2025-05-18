//
//  SearchTab.swift
//  cisum
//
//  Created by Aarav Gupta (github.com/atpugvaraa) on 03/05/25.
//

import SwiftUI

struct SearchTab: View {
    @Binding var searchPath: NavigationPath
    
    @State private var search = Search.shared
    @State private var offsetObserver = PageOffsetObserver.shared
    
    @State private var scrollOffset: CGFloat = 0
    
    let title = Constants.searchTitle
    
    var body: some View {
        NavigationStack(path: $searchPath) {
            NavigationBarView(title: title, blurRadius: search.isSearching ? 24 : 12, blurHeight: search.isSearching ? 140 : 100, scrollOffset: $scrollOffset) {
                if search.isSearching {
                        TabView(selection: $search.activeTab) {
                            SongsSearchTab(scrollOffset: $scrollOffset)
                            .tag(SearchTabs.songs)
                            .background {
                                FindCollectionView {
                                    // Reset and observe the new collection view when TabView appears
                                    if offsetObserver.isObserving {
                                        offsetObserver.remove()
                                    }
                                    offsetObserver.collectionView = $0
                                    offsetObserver.observe()
                                    print($0)
                                }
                            }
                            
                            AlbumsSearchTab(scrollOffset: $scrollOffset)
                            .tag(SearchTabs.albums)
                            
                            ArtistsSearchTab(scrollOffset: $scrollOffset)
                            .tag(SearchTabs.artists)
                            
                            PlaylistsSearchTab(scrollOffset: $scrollOffset)
                            .tag(SearchTabs.playlists)
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                } else {
                    GeometryReader { geo in
                        let safeArea = geo.safeAreaInsets
                        
                        ScrollView {
                            VStack(spacing: 0) {
                                Color.clear
                                    .frame(height: 140)

                                ScrollOffsetBackground { offset in
                                    self.scrollOffset = offset - safeArea.top
                                }
                                .frame(height: 0)

                                content
                            }
                        }
                    }
                }
            }
            .navigationBarStyle(.search)
        }
    }
    
    var content: some View {
        ForEach(0...10, id: \.self) { _ in
            VStack(spacing: 24) {
                Rectangle()
                    .fill(.clear)
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .padding()
            }
        }
    }
}
