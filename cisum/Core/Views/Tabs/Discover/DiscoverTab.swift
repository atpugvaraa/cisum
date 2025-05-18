//
//  DiscoverTab.swift
//  cisum
//
//  Created by Aarav Gupta (github.com/atpugvaraa) on 03/05/25.
//

import SwiftUI

struct DiscoverTab: View {
    @Binding var discoverPath: NavigationPath

    @State private var scrollOffset: CGFloat = 0
    
    let title = Constants.discoverTitle
    
    var body: some View {
        NavigationStack(path: $discoverPath) {
            NavigationBarView(title: title, scrollOffset: $scrollOffset) {
                content
            }
        }
    }
    
    var content: some View {
        Text("Hello, Discover!")
    }
}
