//
//  Discover.swift
//  cisum
//
//  Created by Aarav Gupta (github.com/atpugvaraa) on 03/05/25.
//

import SwiftUI

struct Discover: View {
    @Binding var discoverPath: NavigationPath
    
    let title = Constants.discoverTitle
    
    var body: some View {
        NavigationStack(path: $discoverPath) {
            NavigationBarView(title: title) {
                content
            }
        }
    }
    
    var content: some View {
        Text("Hello, Discover!")
    }
}
