//
//  SelectedTabEnum.swift
//  cisum
//
//  Created by Aarav Gupta (github.com/atpugvaraa) on 29/12/24.
//

import Foundation

enum SelectedTab: Int, CaseIterable {
    case home = 0
    case discover = 1
    case library = 2
    case search = 3
    
    var title: String {
        switch self {
        case .home: return "Home"
        case .discover: return "Discover"
        case .library: return "Library"
        case .search: return "Search"
        }
    }
    
    var icon: String {
        switch self {
        case .home: return "house"
//            "home"
        case .discover: return "globe"
        case .library: return "music.note.list"
        case .search: return "magnifyingglass"
        }
    }
}
