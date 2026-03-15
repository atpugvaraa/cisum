//
//  iOSTabView.swift
//  cisum
//
//  Created by Aarav Gupta on 05/12/25.
//

import SwiftUI

#if os(iOS)
struct iOSTabView<SelectionValue: Hashable>: View {
    @Binding var selection: SelectionValue
    let tabs: [TabViewData<SelectionValue>]
    @Environment(\.tabBarVisibility) private var tabBarVisibility
    @Environment(\.tabBarBottomAccessory) private var tabBarBottomAccessory

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

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                NativeTabView
                    .toolbarVisibility(tabBarVisibility, for: .tabBar)
                    .tabViewBottomAccessory {
                        if let accessory = tabBarBottomAccessory {
                            accessory
                        }
                    }
                    .onChange(of: tabBarVisibility) {
                        print(tabBarVisibility)
                    }
            } else {
                iOS26TabView
            }
        }
        .enableInjection()
    }
    
    // MARK: - Native Adapter (iOS 26+)
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
                }
            }
        }
    }

    // MARK: - Custom TabView (iOS 17+)
    private var iOS26TabView: some View {
        ZStack(alignment: .bottom) {
            // Content
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
            
            // Tab Bar
            VStack(spacing: 0) {
                Spacer()

                if let accessory = tabBarBottomAccessory {
                    let searchTab = tabs.first(where: { $0.role == .search })
                    let isSearchExpanded = selection == searchTab?.value
                
                    accessory
                        .padding(.bottom, tabBarVisibility == .visible ? (isSearchExpanded ? -5 : 5) : -20)
                        .allowsHitTesting(tabBarVisibility == .visible)
                        .animation(.smooth(duration: 0.3), value: tabBarVisibility)
                        .animation(.smooth(duration: 0.3), value: isSearchExpanded)
                }

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
                    .offset(y: tabBarVisibility == .hidden ? 120 : 0)
                    .allowsHitTesting(tabBarVisibility != .hidden)
                    .animation(.smooth(duration: 0.3), value: tabBarVisibility)
                }
            }
        }
    }
}
#endif
