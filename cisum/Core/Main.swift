//
//  Main.swift
//  cisum
//
//  Created by Aarav Gupta on 09/03/24.
//

import SwiftUI

struct Main: View {
  //Miscellaneous
  let AccentColor = Color(red : 0.9764705882352941, green: 0.17647058823529413, blue: 0.2823529411764706)
  let accentColor = Color(red: 0.976, green: 0.176, blue: 0.282, opacity: 0.3)
  @State private var selectedTab = 0

  //Animation Properties
  @EnvironmentObject var viewModel: PlayerViewModel
    @StateObject var mainViewModel = MainViewModel()
  @Namespace var animation
  @State var expandPlayer: Bool = false
  @State private var animateContent: Bool = false

  var body: some View {
    NavigationView {
        //MARK: Tab View
        TabView(selection: $selectedTab) {
          //Tabs
            Home()
            .tabItem {
              if selectedTab == 0 {
                Image("home.fill")
              } else {
                Image("home")
              }
              Text("Home")
            }
            .tag(0)

//          Radio()
//            .tabItem {
//              Image(systemName: "play.square.stack")
//              Text("Radio")
//            }
//            .tag()

            Library()
            .tabItem {
              Image(systemName: "play.square.stack")
              Text("Library")
            }
            .tag(1)

            SearchView()
            .tabItem {
              Image(systemName: "magnifyingglass")
              Text("Search")
            }
            .tag(2)
        }
    }
  }
}

#Preview {
    Main()
}
