import SwiftUI
import DesignSystem
import Utilities

@MainActor
public enum AppRoute: Hashable {
    case home
    case profile
    case settings
    case library
    case recents
    case playlist(id: String)
}

@Observable
@MainActor
public final class AppRouter: Router {

    var path: [AppRoute] = []
    
    public var onTabSwitch: ((TabItem) -> Void)?

    public init() {}

    public func navigate(to route: AnyHashable) {
        if let appRoute = route as? AppRoute {
            switch appRoute {
            case .home:
                onTabSwitch?(.home)
            case .library, .recents:
                onTabSwitch?(.library)
            case .profile, .settings, .playlist:
                path.append(appRoute)
            }
        } else if let stringRoute = route as? String {
            if stringRoute.hasPrefix("playlistDetail:") {
                let id = stringRoute.replacingOccurrences(of: "playlistDetail:", with: "")
                path.append(.playlist(id: id))
            } else if stringRoute == "profile" {
                path.append(.profile)
            } else if stringRoute == "settings" {
                path.append(.settings)
            } else if stringRoute == "tab:search" {
                onTabSwitch?(.search)
            } else if stringRoute == "tab:home" {
                onTabSwitch?(.home)
            } else if stringRoute == "tab:library" {
                onTabSwitch?(.library)
            }
        }
    }
    
    public func pop() {
        if !path.isEmpty {
            path.removeLast()
        }
    }
}
