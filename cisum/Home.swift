//
//  Home.swift
//  cisum
//
//  Created by Aarav Gupta on 18/02/24.
//

import SwiftUI

struct Home: View {
    @State private var selectedTab = 0
    //MARK: Animation Properties
    @State private var expandSheet: Bool = false
    @Namespace private var animation

    var body: some View {
        //MARK: Tab View
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    if selectedTab == 0 {
                        Image("home-selected")
                    } else {
                        Image("home")
                    }
                    Text("Home")
                }
                .tag(0) // Tag for HomeView

            BrowseView()
                .tabItem {
                    Image(systemName: "square.grid.2x2")
                    Text("Browse")
                }
                .tag(1) // Tag for Browse

            LibraryView()
                .tabItem {
                    Image(systemName: "play.square.stack.fill")
                    Text("Library")
                }
                .tag(2) // Tag for Library

            SearchView()
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Search")
                }
                .tag(3) // Tag for Search
        }
        .accentColor(.red)
        .safeAreaInset(edge: .bottom) {
            FloatingPlayer()
        }
        .overlay {
            if expandSheet {
                MusicPlayer(expandSheet: $expandSheet, animation: animation)
                    .transition(.asymmetric(insertion: .identity, removal: .offset(y: -5)))
            }
        }
    }

    //MARK: Floating Player
    @ViewBuilder
    func FloatingPlayer() -> some View {
        ZStack {
            if expandSheet {
                Rectangle()
                    .fill(.clear)
            } else {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .cornerRadius(12)
                    .overlay {
                        //MARK:  Music Info
                        MusicInfo(expandSheet: $expandSheet, animation: animation)
                    }
                    .matchedGeometryEffect(id: "BGView", in: animation)
            }
        }
        .frame(width: 380, height: 60)
        .offset(y: -53)
    }
}

//MARK: Reusable Info
struct MusicInfo: View {
    @State var isMusicPlaying = false
    @Binding var expandSheet: Bool
    var animation: Namespace.ID

    var body: some View {
        HStack(spacing: 0) {
            //MARK: Hero Animation
            ZStack {
                if !expandSheet {
                    GeometryReader { geometry in
                        let size = geometry.size

                        Image("Lady Gaga")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size.width, height: size.height)
                            .clipShape(RoundedRectangle(cornerRadius: expandSheet ? 15 : 5, style: .continuous))
                    }
                    .matchedGeometryEffect(id: "Artwork", in: animation)
                }
            }
            .frame(width: 45, height: 45)

            Text("Bloody Mary")
                .fontWeight(.semibold)
                .lineLimit(1)
                .padding(.horizontal, 15)

            Spacer(minLength: 0)

            Button {

            } label: {
                Image(systemName: "backward.fill")
                    .font(.title2)
                    .foregroundColor(.primary)
            }

            Button {
                withAnimation(.spring()) {
                    isMusicPlaying.toggle()
                }
            } label: {
                Image(systemName: isMusicPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .foregroundColor(.primary)
            }
            .padding(.leading, 25)

            Button {

            } label: {
                Image(systemName: "forward.fill")
                    .font(.title2)
                    .foregroundColor(.primary)
            }
            .padding(.leading, 25)
        }
        .foregroundColor(.primary)
        .padding(.horizontal)
        .contentShape(Rectangle())
        .onTapGesture {
            //MARK: Expanding Player
            withAnimation(.easeInOut(duration: 0.3)) {
                expandSheet = true
            }
        }
    }
}

#Preview {
  Home()
    .preferredColorScheme(.dark)
}
