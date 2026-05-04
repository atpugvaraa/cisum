//
//  TabBarVisibilityKey.swift
//  cisum
//
//  Created by Aarav Gupta on 15/03/26.
//

import SwiftUI

public extension EnvironmentValues {
    public var tabBarVisibility: Visibility {
        get { self[TabBarVisibilityKey.self] }
        set { self[TabBarVisibilityKey.self] = newValue }
    }

    public var tabBarBottomAccessory: AnyView? {
        get { self[TabBarBottomAccessoryKey.self] }
        set { self[TabBarBottomAccessoryKey.self] = newValue }
    }
}

public struct TabBarVisibilityKey: EnvironmentKey {
    public static let defaultValue: Visibility = .visible
}

public struct TabBarBottomAccessoryKey: EnvironmentKey {
    nonisolated(unsafe) public static let defaultValue: AnyView? = nil
}
