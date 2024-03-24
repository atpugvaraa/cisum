//
//  Main.swift
//  cisum
//
//  Created by Aarav Gupta on 09/03/24.
//

import SwiftUI

struct Main: View {
  @State var expandPlayer: Bool = false
  @Namespace var animation
  var body: some View {
    //MARK: Tab View
    TabView {
      //Tabs
      Tabs("Listen Now", "play.circle.fill")
      Tabs("Library", "play.square.stack")
      Tabs("Search", "magnifyingglass")
    }
    //Changing Tab Indicator Color
    .tint(.red)
    .safeAreaInset(edge: .bottom) {
      FloatingPlayer()
    }
    .overlay {
      if expandPlayer {
        Player(expandPlayer: $expandPlayer, animation: animation)
        //Transition
          .transition(.asymmetric(insertion: .identity, removal: .offset(y: -5)))
      }
    }
  }

  //MARK: FLoating Player
  @ViewBuilder
  func FloatingPlayer() -> some View {
    //MARK: Player Expand Animation
    ZStack {
      if expandPlayer {
        Rectangle()
        .fill(.clear)
      } else {
        Rectangle()
        .fill(.ultraThickMaterial)
        .overlay {
          //Music Info
          MusicInfo(expandPlayer: $expandPlayer, animation: animation)
        }
        .matchedGeometryEffect(id: "Background", in: animation)
      }
    }
    .frame(height: 70)
    //MARK: Separator Line
    .overlay(alignment: .bottom, content: {
      Rectangle()
        .fill(.gray.opacity(0.3))
        .frame(height: 1)
  //      .offset(y: -5)
    })
    .offset(y: -49)
  }

  @ViewBuilder
  func Tabs(_ title: String, _ icon: String) -> some View {
    ScrollView(.vertical, showsIndicators: false, content: {
      Text(title)
      .padding(.top, 25)
    })
      .tabItem {
        Image(systemName: icon)
        Text(title)
      }
    //Changing Tab Background Color
      .toolbarBackground(.visible, for: .tabBar)
      .toolbarBackground(.ultraThinMaterial, for: .tabBar)
      //Hiding tab bar
      .toolbar(expandPlayer ? .hidden : .visible, for: .tabBar)
  }
}

//import AVKit
//
//struct Main: View {
//  @State private var selectedTab = 0
//  @State private var expand: Bool = false
//  @Namespace private var animation
//  var body: some View {
//    //MARK: Tab View
//    TabView(selection: $selectedTab) {
//      //MARK: Tabs
//      Tabs(Home(), "home-selected", isSelected: selectedTab == 0)
//        .tag(0)
//      Tabs(Library(), "play.square.stack", isSelected: false)
//        .tag(1)
//      Tabs(Search(), "magnifyingglass", isSelected: false)
//        .tag(2)
//    }
//    .tint(.red)
//    .safeAreaInset(edge: .bottom) {
//      FloatingPlayer()
//    }
//    .overlay {
//      if expand {
//        Player(expand: $expand, animation: animation)
//          .transition(.asymmetric(insertion: .identity, removal: .offset(y: -5)))
//      }
//    }
//  }
//
//  @ViewBuilder
//  func FloatingPlayer() -> some View {
//    ZStack {
//      Rectangle()
//        .fill(.ultraThinMaterial)
//        .overlay {
//          //MARK: MusicInfo
//          MusicInfo(expand: $expand, animation: animation)
//        }
//    }
//    //MARK: Floating Player Height
//    .frame(height: 58)
//    .offset(y: -49)
//  }
//
//  func Tabs<Content: View>(_ tab: Content, _ icon: String, isSelected: Bool) -> some View {
//    var view: some View {
//      tab
//        .tabItem {
//          Label {
//            Text(tabName(tab: tab))
//          } icon: {
//            if isSelected && icon == "home-selected" {
//              Image(icon)
//            } else if !isSelected && icon == "home-selected" {
//              Image("home")
//            } else {
//              Image(systemName: icon)
//            }
//          }
//        }
//        .toolbar(expand ? .hidden : .visible, for: .tabBar)
//    }
//    return view
//  }
//}
//
//func tabName<Content: View>(tab: Content) -> String {
//  return "\(type(of: tab))"
//}
//
//struct MusicInfo: View {
//  @Binding var expand: Bool
//  @State private var isMusicPlaying = false
//  var animation: Namespace.ID
//  var body: some View {
//    HStack(spacing: 0) {
//      ZStack {
//        if !expand {
//          GeometryReader {
//            let size = $0.size
//
//            Image("Image")
//              .resizable()
//              .aspectRatio(contentMode: .fill)
//              .frame(width: size.width, height: size.height)
//              .clipShape(RoundedRectangle(cornerRadius: expand ? 15 : 5, style: .continuous))
//          }
//          .matchedGeometryEffect(id: "Album Cover", in: animation)
//        }
//      }
//      .frame(width: 45, height: 45)
//
//      VStack {
//        Text("Song Name")
//          .fontWeight(.semibold)
//          .lineLimit(1)
//          .padding(.horizontal, 15)
//
//        Text("Artist")
//          .fontWeight(.light)
//          .font(.footnote)
//          .foregroundColor(.gray)
//          .lineLimit(1)
//          .padding(.leading, -45)
//      }
//      .onTapGesture {
//        withAnimation(.easeInOut(duration: 0.3)) {
//          expand = true
//        }
//      }
//
//      Spacer(minLength: 0)
//
//      AirPlayButton()
//        .frame(width: 51, height: 51)
//        .padding(.bottom, 1)
//
//      Button(action: {
//        withAnimation(.spring()) {
//          isMusicPlaying.toggle()
//        }
//      }, label: { Image(systemName: isMusicPlaying ? "pause.fill" : "play.fill")
//          .font(.title)
//          .foregroundColor(.white)
//      })
//      .padding(.trailing, 10)
//      .padding(.leading, 11)
//    }
//    .padding(.horizontal)
//    .frame(height: 58)
//    .contentShape(Rectangle())
//  }
//}
//
//struct AirPlayButton: UIViewRepresentable {
//  func makeUIView(context: Context) -> AVRoutePickerView {
//    let routePickerView = AVRoutePickerView()
//    routePickerView.tintColor = .white
//    routePickerView.activeTintColor = .systemRed
//    routePickerView.prioritizesVideoDevices = false
//    return routePickerView
//  }
//
//  func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
//  }
//}

#Preview {
  Main()
    .preferredColorScheme(.dark)
}
