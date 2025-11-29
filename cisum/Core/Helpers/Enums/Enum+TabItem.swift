//
//  Enum+TabItem.swift
//  cisum
//
//  Created by Aarav Gupta on 05/12/25.
//

enum TabItem: String, CaseIterable {
    case home, discover, library, search
    
    var index: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }
}
