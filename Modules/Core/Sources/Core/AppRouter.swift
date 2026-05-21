import SwiftUI
import DesignSystem
import Utilities

@Observable
@MainActor
public final class AppRouter: Router {
    public var onTabSwitch: ((TabItem) -> Void)?
    public var onPush: ((AppRoute) -> Void)?
    public var onPop: (() -> Void)?

    public init() {}

    public func navigate(to route: AppRoute) {
        switch route {
        case .home:
            onTabSwitch?(.home)
        case .library, .recents:
            onTabSwitch?(.library)
        case .search:
            onTabSwitch?(.search)
        case .profile, .settings, .playlist, .login:
            onPush?(route)
        }
    }
    
    public func pop() {
        onPop?()
    }
}
