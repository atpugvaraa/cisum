//
//  TabBarVisibilityKey.swift
//  cisum
//
//  Created by Aarav Gupta on 15/03/26.
//

import SwiftUI

extension EnvironmentValues {
    var tabBarVisibility: Visibility {
        get { self[TabBarVisibilityKey.self] }
        set { self[TabBarVisibilityKey.self] = newValue }
    }

    var tabBarBottomAccessory: AnyView? {
        get { self[TabBarBottomAccessoryKey.self] }
        set { self[TabBarBottomAccessoryKey.self] = newValue }
    }
}

private struct TabBarVisibilityKey: EnvironmentKey {
    static let defaultValue: Visibility = .visible
}

private struct TabBarBottomAccessoryKey: EnvironmentKey {
    static let defaultValue: AnyView? = nil
}
