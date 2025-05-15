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
            NavigationBarView(title: title, blurRadius: 12, blurHeight: 100) {
                content
            }
            .navigationBarStyle(.search)
        }
    }
    
    var content: some View {
        ForEach(0...20, id: \.self) { _ in
            VStack(spacing: 24) {
                Rectangle()
                    .fill(.clear)
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .padding()
            }
        }
    }
}
