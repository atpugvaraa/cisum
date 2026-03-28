//
//  iOSTabView.swift
//  cisum
//
//  Created by Aarav Gupta on 05/12/25.
//

import SwiftUI
#if os(iOS)
import LNPopupUI
#endif

#if os(iOS)
struct iOSTabView<SelectionValue: Hashable>: View {
    @Environment(PlayerViewModel.self) private var playerViewModel
    @Environment(\.tabBarVisibility) private var tabBarVisibility
    @Environment(\.tabBarBottomAccessory) private var tabBarBottomAccessory
    
    @Binding var selection: SelectionValue
    let tabs: [TabViewData<SelectionValue>]
    
    @State private var showMiniPlayer: Bool = false
    @State private var properties = PlayerProperties.shared
    @Namespace private var namespace

    var searchText: Binding<String>
    var onSearchSubmit: () -> Void
    
    init(
        selection: Binding<SelectionValue>,
        searchText: Binding<String> = .constant(""),
        @TabViewBuilder<SelectionValue> content: () -> [TabViewData<SelectionValue>],
        onSearchSubmit: @escaping () -> Void = {}
    ) {
        self._selection = selection
        self.tabs = content()
        self.searchText = searchText
        self.onSearchSubmit = onSearchSubmit
    }
    
    #if DEBUG
    @ObserveInjection var forceRedraw
    #endif

    private var popupItemID: String {
        playerViewModel.currentVideoId ?? "cisum-now-playing"
    }

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                #if os(iOS)
                NativeTabView
                    .popup(isBarPresented: Binding(
                        get: { true },
                        set: { _ in }
                    ), isPopupOpen: $properties.isPlayerExpanded) {
                        popupContent
                    }
                    .popupBarCustomView(wantsDefaultTapGesture: true, wantsDefaultPanGesture: true, wantsDefaultHighlightGesture: false) {
                        if let accessory = tabBarBottomAccessory {
                            accessory
                                .contentShape(.rect)
                                .onTapGesture {
                                    properties.expandPlayer()
                                }
                        }
                    }
                    .popupBarStyle(.floatingCompact)
                    .popupInteractionStyle(.customizedSnap(percent: 0.05))
                    .popupCloseButtonStyle(.none)
                #endif
            } else {
                iOS26TabView
                    .universalOverlay(show: $showMiniPlayer) {
//                        let searchTab = tabs.first(where: { $0.role == .search })
//                        let isSearchExpanded = selection == searchTab?.value
                        
                        ExpandablePlayer(show: $showMiniPlayer)
//                            .padding(.bottom, isSearchExpanded ? -5 : 0)
//                            .animation(.smooth(duration: 0.3), value: isSearchExpanded)
                            .ignoresSafeArea(.keyboard)
                            .environment(playerViewModel)
                    }
                    .onAppear {
                        showMiniPlayer = true
                    }
            }
        }
        .enableInjection()
    }
    
    // MARK: - Native TabView (iOS 26+)
    @available(iOS 26.0, *)
    private var NativeTabView: some View {
        SwiftUI.TabView(selection: $selection) {
            ForEach(tabs) { tab in
                SwiftUI.Tab(
                    tab.title,
                    systemImage: tab.icon,
                    value: tab.value,
                    role: tab.role?.toNative
                ) {
                    tab.content
                        .toolbarVisibility(tabBarVisibility, for: .tabBar)
                        .animation(.bouncy(duration: 0.3), value: tabBarVisibility)
                }
            }
        }
    }

    @available(iOS 26.0, *)
    private var popupContent: some View {
        let title = playerViewModel.currentTitle
        let subtitle = playerViewModel.currentArtist
        let progress = Float(playerViewModel.currentTime / max(playerViewModel.duration, 1))

        return NowPlayingView(namespace: namespace)
            .environment(playerViewModel)
            .popupItem {
                PopupItem(
                    id: popupItemID,
                    title: title,
                    subtitle: subtitle,
                    image: Image(systemName: "music.note"),
                    progress: progress
                ) {
                    ToolbarItemGroup(placement: .popupBar) {
                        Button {
                            playerViewModel.togglePlayPause()
                        } label: {
                            Image(systemName: playerViewModel.isPlaying ? "pause.fill" : "play.fill")
                        }
                    }
                }
            }
    }

    // MARK: - TabView (iOS 17+)
    private var iOS26TabView: some View {
        ZStack {
            ZStack {
                if let searchTab = tabs.first(where: { $0.role == .search }),
                   selection == searchTab.value {
                    searchTab.content
                } else {
                    ForEach(tabs.filter { $0.role != .search }) { tab in
                        if selection == tab.value {
                            tab.content
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomChrome
        }
    }

    @ViewBuilder
    private var bottomChrome: some View {
        VStack(spacing: 6) {
            if tabBarVisibility == .visible {
                iOS26TabBar(
                    tabs: tabs,
                    activeTab: $selection,
                    showsSearchBar: tabs.contains(where: { $0.role == .search }),
                    searchText: searchText,
                    onSearchTriggered: {
                        if let searchTab = tabs.first(where: { $0.role == .search }) {
                            selection = searchTab.value
                        }
                    },
                    onSearchSubmitted: onSearchSubmit
                )
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.clear)
        .padding(.bottom, tabBarVisibility == .hidden ? -20 : 4)
        .allowsHitTesting(tabBarVisibility != .hidden)
        .animation(.smooth(duration: 0.3), value: tabBarVisibility)
    }
}
#endif
