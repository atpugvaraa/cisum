//
//  SelectedTab.swift
//  cisum
//
//  Created by Aarav Gupta on 29/12/24.
//

import Foundation

enum SelectedTab: Int, CaseIterable {
    case browse = 0
    case library = 1
    case search = 2
    case profile = 3
    
    var title: String {
        switch self {
        case .browse: return "Browse"
        case .library: return "Library"
        case .search: return "Search"
        case .profile: return "Profile"
        }
    }
    
    var icon: String {
        switch self {
        case .browse: return "globe"
        case .library: return "music.note.list"
        case .search: return "magnifyingglass"
        case .profile: return "person.circle.fill"
        }
    }
}
