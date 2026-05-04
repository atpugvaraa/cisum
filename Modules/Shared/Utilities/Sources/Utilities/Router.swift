import SwiftUI

@MainActor
public protocol Router: AnyObject {
    func navigate(to route: AnyHashable)
    func pop()
}

@MainActor
public final class EmptyRouter: Router {
    public init() {}
    public func navigate(to route: AnyHashable) {}
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
