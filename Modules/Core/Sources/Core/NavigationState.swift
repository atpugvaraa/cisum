import SwiftUI
import DesignSystem

@MainActor
@Observable
public final class NavigationState {
    public var selectedTab: TabItem = .home
    public var tabPaths: [TabItem: NavigationPath] = Dictionary(
        uniqueKeysWithValues: TabItem.allCases.map { ($0, NavigationPath()) }
    )

    public init() {}

    public func binding(for tab: TabItem) -> Binding<NavigationPath> {
        Binding(
            get: { self.tabPaths[tab] ?? NavigationPath() },
            set: { self.tabPaths[tab] = $0 }
        )
    }
}
