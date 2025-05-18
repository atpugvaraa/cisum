//
//  LibraryTab.swift
//  cisum
//
//  Created by Aarav Gupta (github.com/atpugvaraa) on 03/05/25.
//

import SwiftUI

struct LibraryTab: View {
    @Binding var libraryPath: NavigationPath
    
    @State private var scrollOffset: CGFloat = 0
    
    let title = Constants.libraryTitle
    
    var body: some View {
        NavigationStack(path: $libraryPath) {
            NavigationBarView(title: title, scrollOffset: $scrollOffset) {
                content
            }
        }
    }
    
    var content: some View {
        Text("Hello, Library!")
    }
}
