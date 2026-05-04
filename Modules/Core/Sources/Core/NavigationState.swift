import SwiftUI
import DesignSystem

@MainActor
public final class NavigationState: ObservableObject {
    @Published public var selectedTab: TabItem = .home
    @Published public var tabPaths: [TabItem: NavigationPath] = Dictionary(
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
