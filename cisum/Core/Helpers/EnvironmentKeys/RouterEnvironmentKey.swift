//
//  RouterEnvironmentKey.swift
//  cisum
//
//  Created by Aarav Gupta on 15/03/26.
//

import SwiftUI

private struct RouterEnvironmentKey: EnvironmentKey {
    static let defaultValue: Router = Router.shared
}

extension EnvironmentValues {
    var router: Router {
        get { self[RouterEnvironmentKey.self] }
        set { self[RouterEnvironmentKey.self] = newValue }
    }
}
