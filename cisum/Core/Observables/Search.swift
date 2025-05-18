//
//  Search.swift
//  cisum
//
//  Created by Aarav Gupta on 17/05/25.
//

import SwiftUI

@Observable
class Search {
    static let shared = Search()
    
    var activeTab: SearchTabs = .songs
    var isSearching: Bool = false
    var keyword = ""
}
