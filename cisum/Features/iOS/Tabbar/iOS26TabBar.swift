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
    @State private var lastVisibleSelection: SelectionValue?
    
    @State private var isSearchExpanded: Bool = false
    
    @FocusState private var isKeyboardActive: Bool
    
    #if DEBUG
    @ObserveInjection var forceRedraw
    #endif

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let visibleTabs = tabs.filter { $0.role != .search }
            let tabsCount = CGFloat(max(visibleTabs.count, 1))
            let tabItemWidth = max(min(size.width / tabsCount, 90), 60)
            let tabItemHeight: CGFloat = 56
            
            ZStack {
                if !tabs.isEmpty || showsSearchBar {
                    let mainLayout = isKeyboardActive ? AnyLayout(ZStackLayout(alignment: .leading)) : AnyLayout(HStackLayout(spacing: 12))
                    
                    mainLayout {
                        let tabLayout = isSearchExpanded ? AnyLayout(ZStackLayout()) : AnyLayout(HStackLayout(spacing: 0))
                        
                        tabLayout {
                            ForEach(visibleTabs) { tab in
                                TabItemView(
                                    tab,
                                    width: isSearchExpanded ? 45 : tabItemWidth,
                                    height: isSearchExpanded ? 45 : tabItemHeight,
                                    visibleTabs: visibleTabs
                                )
                                .opacity(isSearchExpanded ? ((activeTab == tab.value || (!visibleTabs.contains(where: { $0.value == activeTab }) && lastVisibleSelection == tab.value)) ? 1 : 0) : 1)
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
                                        withAnimation(bouncyAnimation) {
                                            isSearchExpanded = false
                                            isKeyboardActive = false
                                            if let last = lastVisibleSelection {
                                                activeTab = last
                                            }
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
            .onChange(of: activeTab) { newValue, _ in
                // Update lastVisibleSelection if the new activeTab is one of the visible tabs
                if visibleTabs.contains(where: { $0.value == newValue }) {
                    lastVisibleSelection = newValue
                }
                withAnimation(.bouncy) {
                    setInitialOffset(width: tabItemWidth)
                }
            }
        }
        .frame(height: 56)
        .padding(.horizontal, isSearchExpanded ? (isKeyboardActive ? 10 : 25) : 0)
        .padding(.bottom, isKeyboardActive ? 10 : -10)
        .animation(bouncyAnimation, value: dragOffset)
        .animation(bouncyAnimation, value: isActive)
        .animation(bouncyAnimation, value: activeTab)
        .animation(bouncyAnimation, value: isKeyboardActive)
        .enableInjection()
    }
    
    private var bouncyAnimation: Animation {
        if #available(iOS 26.0, *) {
            .bouncy
        } else {
            .smooth(duration: 0.35, extraBounce: 0.185)
        }
    }
    
    private func setInitialOffset(width: CGFloat) {
        let visible = tabs.filter { $0.role != .search }
        if let index = visible.firstIndex(where: { $0.value == activeTab }) {
            dragOffset = CGFloat(index) * width
            lastVisibleSelection = activeTab
            isInitialOffsetSet = true
        } else if let last = lastVisibleSelection, let idx = visible.firstIndex(where: { $0.value == last }) {
            // Restore to previously remembered visible selection if still present
            dragOffset = CGFloat(idx) * width
            isInitialOffsetSet = true
        } else if let first = visible.first {
            // No known previous visible selection; default to first tab but do not overwrite lastVisibleSelection
            if let idx = visible.firstIndex(where: { $0.value == first.value }) {
                dragOffset = CGFloat(idx) * width
            }
            isInitialOffsetSet = true
        }
    }
    
    @ViewBuilder
    private func TabItemView(_ tab: TabViewData<SelectionValue>, width: CGFloat, height: CGFloat, visibleTabs: [TabViewData<SelectionValue>]) -> some View {
        let tabCount = CGFloat(max(visibleTabs.count - 1, 0))
        
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
                                dragOffset = max(min(newDragOffset, tabCount * width), 0)
                    } else {
                        lastDragOffset = dragOffset
                    }
                })
                .onEnded({ value in
                    lastDragOffset = nil
                    let landingIndex  = Int((dragOffset / width).rounded())
                    if visibleTabs.indices.contains(landingIndex) {
                        dragOffset = CGFloat(landingIndex) * width
                        activeTab = visibleTabs[landingIndex].value
                    }
                })
        )
        .simultaneousGesture(
            TapGesture()
                .onEnded({ _ in
                    activeTab = tab.value
                    if let index = visibleTabs.firstIndex(where: { $0.value == activeTab }) {
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
                        withAnimation(bouncyAnimation) {
                            isSearchExpanded = true
                            let visible = tabs.filter { $0.role != .search }
                            if visible.contains(where: { $0.value == activeTab }) {
                                lastVisibleSelection = activeTab
                            }
                            onSearchTriggered()
                        }
                    }
                    .allowsHitTesting(!isSearchExpanded)
                
                if isSearchExpanded {
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
                withAnimation(bouncyAnimation) {
                    isKeyboardActive = false
                }
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
