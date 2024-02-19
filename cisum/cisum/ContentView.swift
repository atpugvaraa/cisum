//
//  ContentView.swift
//  cisum
//
//  Created by Aarav Gupta on 18/02/24.
//
import SwiftUI

struct ContentView: View {
    @State var expand = false
    
    @Namespace var animation
    
    var body: some View {
        ZStack(alignment: Alignment(horizontal: .center, vertical: .bottom), content: {
            TabView {
                ListenNowView()
                    .tabItem {
                        Image(systemName: "play.circle")
                        Text("Listen Now")
                    }
                    .tag(0) // Tag for ListenNowView
    
                BrowseView()
                    .tabItem {
                        Image(systemName: "square.grid.2x2")
                        Text("Browse")
                    }
                    .tag(1) // Tag for Browse

                RadioView()
                    .tabItem {
                        Image(systemName: "dot.radiowaves.left.and.right")
                        Text("Radio")
                    }
                    .tag(2) // Tag for Radio

                LibraryView()
                    .tabItem {
                        Image(systemName: "play.square.stack.fill")
                        Text("Library")
                    }
                    .tag(3) // Tag for Library

                SearchView()
                    .tabItem {
                        Image(systemName: "magnifyingglass")
                        Text("Search")
                    }
                    .tag(4) // Tag for Search
            }
            .accentColor(.red)
            
            Player(animation: animation, expand: $expand)
                .padding(.horizontal, 0)
                .padding(.bottom, 5)
        })
    }
}

#Preview {
    ContentView()
}
