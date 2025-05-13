//
//  Library.swift
//  cisum
//
//  Created by Aarav Gupta (github.com/atpugvaraa) on 03/05/25.
//

import SwiftUI

struct Library: View {
    @Binding var libraryPath: NavigationPath
    
    let title = Constants.libraryTitle
    
    var body: some View {
        NavigationStack(path: $libraryPath) {
            NavigationBarView(title: title) {
                content
            }
        }
    }
    
    var content: some View {
        Text("Hello, Library!")
    }
}
