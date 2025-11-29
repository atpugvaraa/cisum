//
//  iOS26TabBar.swift
//  cisum
//
//  Created by Aarav Gupta on 05/12/25.
//

import SwiftUI

struct iOS26TabBar<SelectionValue: Hashable>: View {
    let tabs: [TabViewData<SelectionValue>]
    @Binding var activeTab: SelectionValue
    var showsSearchBar: Bool = false
    
    @Binding var searchText: String
    var onSearchTriggered: () -> Void
    var onSearchSubmitted: () -> Void
    
    // View Properties
    @GestureState private var isActive = false
    @State private var isInitialOffsetSet = false
    @State private var dragOffset: CGFloat = 0
    @State private var lastDragOffset: CGFloat?
    
    @State private var isSearchExpanded: Bool = false
    
    @FocusState private var isKeyboardActive: Bool
    
    #if DEBUG
    @ObserveInjection var forceRedraw
    #endif

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let tabsCount = CGFloat(tabs.count - 1)
            let tabItemWidth = max(min(size.width / tabsCount, 90), 60)
            let tabItemHeight: CGFloat = 56
            
            ZStack {
                if !tabs.isEmpty || showsSearchBar {
                    let mainLayout = isKeyboardActive ? AnyLayout(ZStackLayout(alignment: .leading)) : AnyLayout(HStackLayout(spacing: 12))
                    
                    mainLayout {
                        let tabLayout = isSearchExpanded ? AnyLayout(ZStackLayout()) : AnyLayout(HStackLayout(spacing: 0))
                        
                        tabLayout {
                            ForEach(tabs) { tab in
                                TabItemView(
                                    tab,
                                    width: isSearchExpanded ? 45 : tabItemWidth,
                                    height: isSearchExpanded ? 45 : tabItemHeight
                                )
                                .opacity(isSearchExpanded ? (activeTab == tab.value ? 1 : 0) : 1)
                            }
                        }
                        .background(alignment: .leading) {
                            ZStack {
                                Capsule(style: .continuous)
                                    .stroke(.gray.opacity(0.25), lineWidth: 3)
                                    .opacity(isActive ? 1 : 0)
                                
                                Capsule(style: .continuous)
                                    .fill(.background)
                            }
                            .compositingGroup()
                            .frame(width: tabItemWidth, height: tabItemHeight)
                            .scaleEffect(isActive ? 1.3 : 1)
                            .offset(x: isSearchExpanded ? 0 : dragOffset)
                            .opacity(isSearchExpanded ? 0 : 1)
                        }
                        .padding(isSearchExpanded ? 0 : 3)
                        .background(TabBarBackground())
                        .overlay {
                            if isSearchExpanded {
                                Capsule()
                                    .foregroundStyle(.clear)
                                    .contentShape(.capsule)
                                    .onTapGesture {
                                        withAnimation(.bouncy) {
                                            isSearchExpanded = false
                                            isKeyboardActive = false
                                        }
                                    }
                            }
                        }
                        .opacity(isKeyboardActive ? 0 : 1)
                        
                        if showsSearchBar {
                            ExpandableSearchBar(height: isSearchExpanded ? 45 : tabItemHeight)
                        }
                    }
                    .geometryGroup()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .onAppear {
                setInitialOffset(width: tabItemWidth)
            }
            .onChange(of: activeTab) { _, _ in
                withAnimation(.bouncy) {
                    setInitialOffset(width: tabItemWidth)
                }
            }
        }
        .frame(height: 56)
        .padding(.horizontal, isKeyboardActive ? 10 : 25)
        .padding(.bottom, isKeyboardActive ? 10 : 0)
        .animation(.bouncy, value: dragOffset)
        .animation(.bouncy, value: isActive)
        .animation(.smooth, value: activeTab)
        .animation(.bouncy, value: isKeyboardActive)
        .enableInjection()
    }
    
    // ... (Keep setInitialOffset, TabItemView, TabBarBackground same as before) ...
    private func setInitialOffset(width: CGFloat) {
        if let index = tabs.firstIndex(where: { $0.value == activeTab }) {
            dragOffset = CGFloat(index) * width
            isInitialOffsetSet = true
        }
    }
    
    @ViewBuilder
    private func TabItemView(_ tab: TabViewData<SelectionValue>, width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 6) {
            Image(systemName: tab.icon)
                .font(.title2)
                .symbolVariant(.fill)
            
            if !isSearchExpanded {
                Text(tab.title)
                    .font(.caption2)
                    .lineLimit(1)
            }
        }
        .foregroundStyle(activeTab == tab.value ? accentColor : .primary)
        .frame(width: width, height: height)
        .contentShape(.capsule)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .updating($isActive, body: { _, out, _ in out = true })
                .onChanged({ value in
                    let xOffset = value.translation.width
                    if let lastDragOffset {
                        let newDragOffset = xOffset + lastDragOffset
                        dragOffset = max(min(newDragOffset, CGFloat(tabs.count - 1) * width), 0)
                    } else {
                        lastDragOffset = dragOffset
                    }
                })
                .onEnded({ value in
                    lastDragOffset = nil
                    let landingIndex  = Int((dragOffset / width).rounded())
                    if tabs.indices.contains(landingIndex) {
                        dragOffset = CGFloat(landingIndex) * width
                        activeTab = tabs[landingIndex].value
                    }
                })
        )
        .simultaneousGesture(
            TapGesture()
                .onEnded({ _ in
                    activeTab = tab.value
                    if let index = tabs.firstIndex(where: { $0.value == activeTab }) {
                        dragOffset = CGFloat(index) * width
                    }
                })
        )
        .geometryGroup()
    }
    
    @ViewBuilder
    private func TabBarBackground() -> some View {
        ZStack {
            Capsule(style: .continuous)
                .stroke(.gray.opacity(0.25), lineWidth: 1.5)
            Capsule(style: .continuous)
                .fill(.background.opacity(0.8))
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .compositingGroup()
    }
    
    @ViewBuilder
    private func ExpandableSearchBar(height: CGFloat) -> some View {
        let searchLayout = isKeyboardActive ? AnyLayout(HStackLayout(spacing: 12)) : AnyLayout(ZStackLayout(alignment: .trailing))
        
        searchLayout {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(isSearchExpanded ? .body : .title2)
                    .foregroundStyle(isSearchExpanded ? .gray : .primary)
                    .frame(width: isSearchExpanded ? nil : height, height: height)
                    .onTapGesture {
                        withAnimation(.bouncy) {
                            isSearchExpanded = true
                            onSearchTriggered()
                        }
                    }
                    .allowsHitTesting(!isSearchExpanded)
                
                if isSearchExpanded {
                    // CHANGED: Use bound searchText
                    TextField("Search...", text: $searchText)
                        .focused($isKeyboardActive)
                        .onSubmit {
                            onSearchSubmitted()
                        }
                }
            }
            .padding(.horizontal, isSearchExpanded ? 15 : 0)
            .padding(isSearchExpanded ? 0 : 3)
            .background(TabBarBackground())
            .geometryGroup()
            .zIndex(1)
            
            Button {
                isKeyboardActive = false
            } label: {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundStyle(.primary)
                    .frame(width: height, height: height)
                    .background(TabBarBackground())
            }
            .opacity(isKeyboardActive ? 1 : 0)
        }
    }
    
    var accentColor: Color { .blue }
}
