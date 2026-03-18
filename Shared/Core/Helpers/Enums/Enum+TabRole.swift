//
//  Enum+TabRole.swift
//  cisum
//
//  Created by Aarav Gupta on 05/12/25.
//

import SwiftUI

/// Represents the role of a tab, matching iOS 18 API.
public enum TabRole {
    case search
}

extension TabRole {
    @available(macOS 15.0, *)
    @available(iOS 26.0, *)
    var toNative: SwiftUI.TabRole? {
        switch self {
        case .search:
            return SwiftUI.TabRole.search
        }
    }
}
