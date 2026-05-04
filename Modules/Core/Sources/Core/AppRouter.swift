import SwiftUI
import DesignSystem
import Utilities

@MainActor
public enum AppRoute: Hashable {
    case home
    case profile
    case playlist(id: String)
}

@Observable
@MainActor
public final class AppRouter: Router {

    var path: [AppRoute] = []
    
    public var onTabSwitch: ((TabItem) -> Void)?

    public func navigate(to route: AnyHashable) {
        if let appRoute = route as? AppRoute {
            path.append(appRoute)
        } else if let stringRoute = route as? String {
            if stringRoute.hasPrefix("playlistDetail:") {
                let id = stringRoute.replacingOccurrences(of: "playlistDetail:", with: "")
                path.append(.playlist(id: id))
            } else if stringRoute == "profile" {
                path.append(.profile)
            } else if stringRoute == "tab:search" {
                onTabSwitch?(.search)
            }
        }
    }
    
    public func pop() {
        if !path.isEmpty {
            path.removeLast()
        }
    }
}
