//
//  SearchPage.swift
//  cisum
//
//  Created by Aarav Gupta on 29/12/24.
//

import SwiftUI

struct SearchPage: View {
    @Binding var searchPath: NavigationPath
    
    var body: some View {
        NavigationStack(path: $searchPath) {
            Text("Hello, Search!")
        }
    }
}
