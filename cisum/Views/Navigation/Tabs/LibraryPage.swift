//
//  LibraryPage.swift
//  cisum
//
//  Created by Aarav Gupta on 29/12/24.
//

import SwiftUI

struct LibraryPage: View {
    @Binding var libraryPath: NavigationPath
    
    var body: some View {
        NavigationStack(path: $libraryPath) {
            Text("Hello, Library!")
        }
    }
}
