import SwiftUI

@MainActor
public enum AppRoute: Hashable {
    case home
    case profile
    case settings
    case search
    case library
    case recents
    case playlist(id: String)
    case login
}

@MainActor
public protocol Router: AnyObject {
    func navigate(to route: AppRoute)
    func pop()
}

@MainActor
public final class EmptyRouter: Router {
    public init() {}
    public func navigate(to route: AppRoute) {}
    public func pop() {}
}

private struct RouterKey: @preconcurrency EnvironmentKey {
    @MainActor static let defaultValue: Router = EmptyRouter()
}

public extension EnvironmentValues {
    var router: Router {
        get { self[RouterKey.self] }
        set { self[RouterKey.self] = newValue }
    }
}

public extension View {
    @MainActor
    func usingRouter(_ router: Router = EmptyRouter()) -> some View {
        environment(\.router, router)
    }
}
