//
//  iOSTabView.swift
//  cisum
//
//  Created by Aarav Gupta on 05/12/25.
//

import SwiftUI

#if os(iOS)
public struct iOSTabView<SelectionValue: Hashable>: View {
    @Binding var selection: SelectionValue
    let tabs: [TabViewData<SelectionValue>]
    
//    @State private var bottomAccessory: AnyView?
    
    var searchText: Binding<String>
    var onSearchSubmit: () -> Void
    
    public init(selection: Binding<SelectionValue>,
                searchText: Binding<String> = .constant(""),
                @TabViewBuilder<SelectionValue> content: () -> [TabViewData<SelectionValue>],
                onSearchSubmit: @escaping () -> Void = {}) {
        self._selection = selection
        self.tabs = content()
        self.searchText = searchText
        self.onSearchSubmit = onSearchSubmit
    }
    
    public var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                NativeTabView
            } else {
                iOS26TabView
            }
        }
//        .onPreferenceChange(TabViewBottomAccessoryKey.self) { value in
//            self.bottomAccessory = value?.view
//        }
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
                        .ignoresSafeArea()
                }
            }
        }
//        .overlay(alignment: .bottom) {
//            if let bottomAccessory {
//                bottomAccessory
//                    .padding(.bottom, 60)
//            }
//        }
    }

    // MARK: - Custom TabView (iOS 17+)
    private var iOS26TabView: some View {
        ZStack(alignment: .bottom) {
            // Content
            ZStack {
                if let searchTab = tabs.first(where: { $0.role == .search }),
                   selection == searchTab.value {
                    searchTab.content
                        .ignoresSafeArea()
                } else {
                    ForEach(tabs.filter { $0.role != .search }) { tab in
                        if selection == tab.value {
                            tab.content
                                .ignoresSafeArea()
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Tab Bar
            VStack(spacing: 0) {
                Spacer()
                
                iOS26TabBar(
                    tabs: tabs.filter { $0.role != .search },
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
    }
}
#endif
