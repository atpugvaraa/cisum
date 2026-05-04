import SwiftUI
import DesignSystem
import Utilities

public struct RootView: View {
    public let cisum: cisumModule
    
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var navigationState: NavigationState

#if os(iOS)
    @State private var isScrollingDown = false
    @State private var storedOffset: CGFloat = 0
    @State var scrollPhase: ScrollPhases = .idle
    @State var tabBarVisibility: Visibility = .visible
    @State private var expandMiniPlayer: Bool = false
    @Namespace private var playerAnimationNamespace
#else
    @Environment(SearchOverlayController.self) private var searchOverlay
    @Environment(\.isDynamicPlayerExpanded) private var isDynamicPlayerExpanded
#endif

    public init(module: cisumModule) {
        self.cisum = module
        self.navigationState = module.navigationState
    }

    public var body: some View {
#if os(iOS)
        iOSTabView(
            selection: selectedTabBinding,
            expandMiniPlayer: $expandMiniPlayer,
            playerAnimationNamespace: playerAnimationNamespace,
            searchText: cisum.searchText,
            playerContent: cisum.expandablePlayer(
                show: .constant(true),
                isExpanded: $expandMiniPlayer,
                collapsedFrame: .zero
            ),
            accentColor: cisum.playerAccentColor
        ) {
            Tab("Home", systemImage: "house.fill", value: TabItem.home) {
                tabRoot(for: .home) {
                    cisum.homeView
                }
            }

            Tab("Discover", systemImage: "globe", value: TabItem.discover) {
                tabRoot(for: .discover) {
                    cisum.discoverView
                }
            }

            Tab("Library", systemImage: "music.note.list", value: TabItem.library) {
                tabRoot(for: .library) {
                    cisum.libraryView
                }
            }

            Tab("Search", systemImage: "magnifyingglass", value: TabItem.search, role: .search) {
                tabRoot(for: .search) {
                    cisum.searchView
                }
            }
        } onSearchSubmit: {
            cisum.performSearch()
        }
        .tabbarBottomViewAccessory {
            cisum.miniPlayer(
                isExpanded: $expandMiniPlayer,
                namespace: playerAnimationNamespace
            )
        }
        .tabbarVisibility(tabBarVisibility)
        .animation(.smooth(duration: 0.3), value: tabBarVisibility)
        .environment(\.playerPresentationActions, playerPresentationActions)
        .systemVolumeController(cisum.systemVolumeController, showsSystemVolumeHUD: false)
        .environment(\.router, cisum.router)
        .onChange(of: navigationState.selectedTab) { _, _ in
            if tabBarVisibility != .visible {
                tabBarVisibility = .visible
            }
        }
#else
        tabSurface
            .onPreferenceChange(SearchOverlayContextPreferenceKey.self) { newContext in
                searchOverlay.updateContext(newContext)
            }
            .overlay(alignment: .top) {
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: 20)
                    .allowWindowDrag()

                SearchOverlayBar()
                    .padding(8)
            }
            .overlay(alignment: .topLeading) {
                ProfileButton()
                    .padding(8)
            }
            .overlay(alignment: .topTrailing) {
                DynamicPlayerIsland()
                    .padding(8)
            }
            .background {
                backgroundFill
            }
            .environment(\.isDynamicPlayerExpanded, isDynamicPlayerExpanded)
            .ignoresSafeArea()
            .usingRouter()
#endif
    }

#if os(iOS)
    private var selectedTabBinding: Binding<TabItem> {
        Binding(
            get: { navigationState.selectedTab },
            set: { navigationState.selectedTab = $0 }
        )
    }

    private var playerPresentationActions: PlayerPresentationActions {
        PlayerPresentationActions(
            expand: {
                expandPlayer()
            },
            collapse: {
                collapsePlayer()
            },
            toggle: {
                togglePlayerExpansion()
            }
        )
    }

    private func expandPlayer() {
        guard !expandMiniPlayer else { return }
        withAnimation(.playerExpandAnimation) {
            expandMiniPlayer = true
        }
    }

    private func collapsePlayer() {
        guard expandMiniPlayer else { return }
        withAnimation(.playerExpandAnimation) {
            expandMiniPlayer = false
        }
    }

    private func togglePlayerExpansion() {
        if expandMiniPlayer {
            collapsePlayer()
        } else {
            expandPlayer()
        }
    }

    @ViewBuilder
    private func tabRoot<Content: View>(for tab: TabItem, @ViewBuilder content: () -> Content) -> some View {
        NavigationStack(path: navigationState.binding(for: tab)) {
            content()
                .ignoresSafeArea()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .onScrollOffsetChange { oldValue, newValue in
                    let scrollingDown = oldValue < newValue

                    if self.isScrollingDown != scrollingDown {
                        let adjustedOffset = newValue - (tabBarVisibility == .hidden ? 20 : 0)
                        if storedOffset != adjustedOffset {
                            storedOffset = adjustedOffset
                        }
                        self.isScrollingDown = scrollingDown
                    }

                    let diff = newValue - storedOffset
                    if scrollPhase == .interacting {
                        if diff > AppConstants.hideThresholds {
                            if tabBarVisibility != .hidden {
                                tabBarVisibility = .hidden
                            }
                        } else if diff < AppConstants.showThresholds {
                            if tabBarVisibility != .visible {
                                tabBarVisibility = .visible
                            }
                        }
                    }
                }
                .onScrollPhaseUpdate { _, newPhase in
                    if scrollPhase != newPhase {
                        scrollPhase = newPhase
                    }
                }
        }
    }
#else
    @ViewBuilder
    private var backgroundFill: some View {
        if #available(macOS 26.0, *) {
            Rectangle()
                .fill(.clear)
                .glassEffect(.regular, in: .rect)
        } else {
            Rectangle()
                .fill(.ultraThinMaterial.opacity(0.92))
        }
    }

    @ViewBuilder
    private var tabSurface: some View {
        tabRoot(for: navigationState.selectedTab) {
            selectedTabContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .contentMargins(.top, 80)
        .contentMargins(.trailing, isDynamicPlayerExpanded.wrappedValue ? 430 : 0)
        .animation(.playerExpandAnimation, value: isDynamicPlayerExpanded.wrappedValue)
    }

    @ViewBuilder
    private var selectedTabContent: some View {
        switch navigationState.selectedTab {
        case .home:
            module.homeView
        case .discover:
            module.discoverView
        case .library:
            module.libraryView
        case .search:
            module.searchView
        }
    }

    @ViewBuilder
    private func tabRoot<Content: View>(for tab: TabItem, @ViewBuilder content: () -> Content) -> some View {
        NavigationStack(path: navigationState.binding(for: tab)) {
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
#endif
}
