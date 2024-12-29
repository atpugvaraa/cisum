//
//  BrowsePage.swift
//  cisum
//
//  Created by Aarav Gupta on 29/12/24.
//

import SwiftUI

struct BrowsePage: View {
    @Binding var browsePath: NavigationPath
    
    var body: some View {
        NavigationStack(path: $browsePath) {
            Text("Hello, Browse!")
        }
    }
}
