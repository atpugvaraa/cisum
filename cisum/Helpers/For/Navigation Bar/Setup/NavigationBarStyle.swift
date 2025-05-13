//
//  NavigationBarStyle.swift
//  cisum
//
//  Created by Aarav Gupta (github.com/atpugvaraa) on 13/05/25.
//

import SwiftUI

struct NavigationBarStyle {
    // Define the style options
    enum StyleType {
        case standard
        case search
    }
    
    // Core properties that define your style
    var styleType: StyleType
    var backgroundColor: Color
    var titleColor: Color
    var iconColor: Color
    var showSearchBar: Bool
    var blurRadius: CGFloat
    var maskHeight: CGFloat
    
    // Predefined styles as static properties
    static let standard = NavigationBarStyle(
        styleType: .standard,
        backgroundColor: .clear,
        titleColor: .primary,
        iconColor: .primary,
        showSearchBar: false,
        blurRadius: 10,
        maskHeight: 130
    )
    
    static let search = NavigationBarStyle(
        styleType: .search,
        backgroundColor: .clear,
        titleColor: .primary,
        iconColor: .primary,
        showSearchBar: true,
        blurRadius: 15,
        maskHeight: 170
    )
}
