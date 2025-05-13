//
//  Search.swift
//  cisum
//
//  Created by Aarav Gupta (github.com/atpugvaraa) on 03/05/25.
//

import SwiftUI

struct Search: View {
    @Binding var searchPath: NavigationPath
    
    let title = Constants.searchTitle
    
    var body: some View {
        NavigationStack(path: $searchPath) {
            NavigationBarView(title: title) {
                content
            }
            .navigationBarStyle(.search)
        }
    }
    
    var content: some View {
        Text("Hello, Search!")
    }
}
