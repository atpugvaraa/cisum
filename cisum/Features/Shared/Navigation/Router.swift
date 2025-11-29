//
//  Router.swift
//  cisum
//
//  Created by Aarav Gupta on 14/03/26.
//

import SwiftUI

enum Routes: Hashable {
    // Auth
//    case signup
//    case login
//    case resetPassword
//    case forgotPassword(email: String)
    
    // Navigation
    case home
    case discover
    case library
    case search
    case profile
    case settings
}

@Observable
class Router {
    static let shared = Router()
    
    var path = NavigationPath()
    
    func navigate(to route: Routes) {
        path.append(route)
    }
    
    func popToRoot() {
        path.removeLast(path.count)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }
}

