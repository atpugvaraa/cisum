//
//  HomeTab.swift
//  cisum
//
//  Created by Aarav Gupta (github.com/atpugvaraa) on 03/05/25.
//

import SwiftUI

struct HomeTab: View {
    @Binding var homePath: NavigationPath
    
    @State private var scrollOffset: CGFloat = 0
    
    let title = Constants.homeTitle
    
    var body: some View {
        NavigationStack(path: $homePath) {
            ZStack {
                background
                
                NavigationBarView(title: title, scrollOffset: $scrollOffset, icon: "person.fill") {
                    content
                }
            }
        }
    }
    
    var content: some View {
        Text("Hello, Home!")
    }
    
    var background: some View {
        ZStack {
            Rectangle()
                .fill(Colors.dynamicAccent)
            
            LinearGradient(colors: [.clear] + Array(repeating: Color(.systemBackground), count: 4), startPoint: .top, endPoint: .bottom)
        }
        .ignoresSafeArea()
    }
}
