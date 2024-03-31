//
//  Main.swift
//  cisum
//
//  Created by Aarav Gupta on 09/03/24.
//

import SwiftUI

struct Main: View {
  let AccentColor = Color(red : 0.9764705882352941, green: 0.17647058823529413, blue: 0.2823529411764706)
  @State private var selectedTab = 0
    //Side Menu Properties
    var sideMenuWidth: CGFloat = 200
    @State private var offsetX: CGFloat = 0
    @State private var lastOffsetX: CGFloat = 0
    @State private var progress: CGFloat = 0
  //Animation Properties
  @State var expandPlayer: Bool = false
  @Namespace var animation
    @State private var showMenu: Bool = false
    var body: some View {
        AnimatedSideBar(
            rotatesWhenExpanded: true,
            disablesInteraction: true,
            sideMenuWidth: 200,
            cornerRadius: 25,
            showMenu: $showMenu
        ) { safeArea in
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
                
                Library()
                    .tabItem {
                        Image(systemName: "play.square.stack")
                        Text("Library")
                    }
                    .tag(1)
                
                Search()
                    .tabItem {
                        Image(systemName: "magnifyingglass")
                        Text("Search")
                    }
                    .tag(2)
            }
        } menuView: { safeArea in
            sideMenuView(safeArea)
        } background: {
            Rectangle()
                .fill(.sideMenu)
        }
        .accentColor(AccentColor)
        //Hiding tab bar
        .toolbar(expandPlayer ? .hidden : .visible, for: .tabBar)
        .safeAreaInset(edge: .bottom) {
            FloatingPlayer()
        }
        .overlay {
            Button(action: {
                        withAnimation(.snappy(duration: 0.3, extraBounce: 0)) {
                            if showMenu {
                                reset()
                            } else {
                                showSideBar()
                            }
                        }
                    }, label: {
                Image("Image")
                    .resizable()
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 25.0))
            })
            .padding(.top, -338)
            .padding(.leading, 300)
        }
        .overlay {
            if expandPlayer {
                Player(expandPlayer: $expandPlayer, animation: animation)
//                Transition
                    .transition(.asymmetric(insertion: .identity, removal: .offset(y: -5)))
            }
        }
    }
    
    //MARK: Show Side Bar
    func showSideBar() {
        offsetX = sideMenuWidth
        lastOffsetX = offsetX
        showMenu = true
        progress = 1 //complete the progress
    }
    
    //MARK: Reset to initial state
    func reset() {
        offsetX = 0
        lastOffsetX = 0
        showMenu = false
        progress = 0 // Reset the progress
    }
    
    //MARK: Side Bar Menu
    @ViewBuilder
    func sideMenuView(_ safeArea: UIEdgeInsets) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("cisum")
                .font(.largeTitle.bold())
                .padding(.bottom, 10)
            sideMenuTabs(.profile) {
                Profile()
            }
            sideMenuTabs(.downloads) {
                Downloads()
            }
            sideMenuTabs(.settings) {
                Settings()
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 20)
        .padding(.top, safeArea.top)
        .padding(.bottom, safeArea.bottom)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .environment(\.colorScheme, .dark)
    }
    
    //sideMenuTabs
    @ViewBuilder
    func sideMenuTabs<Content: View>(_ tab: Tab, onTap: @escaping () -> Content) -> some View {
        Button(action: {
               // Present the associated view
            tab.view()
           }) {
            HStack(spacing: 12) {
                Image(systemName: tab.rawValue)
                    .font(.title3)
                
                Text(tab.title)
                    .font(.callout)
                
                Spacer(minLength: 0)
            }
            .padding(.vertical, 10)
            .contentShape(.rect)
            .foregroundColor(AccentColor)
        }
    }
    
    //Tabs
    enum Tab: String, CaseIterable {
        case profile = "person.crop.circle"
        case downloads = "arrow.down.circle"
        case settings = "gear" 
        
        func view() -> some View {
            switch self {
            case .profile:
                return AnyView(Profile())
            case .downloads:
                return AnyView(Downloads())
            case .settings:
                return AnyView(Settings())
            }
        }
        
        var title: String {
            switch self {
            case .profile:
                return "Profile"
            case .downloads:
                return "Downloads"
            case .settings:
                return "Settings"
            }
        }
    }
    
  //MARK: Floating Player
  @ViewBuilder
  func FloatingPlayer() -> some View {
    //MARK: Player Expand Animation
    ZStack {
      if expandPlayer {
        Rectangle()
          .fill(.clear)
      } else {
        RoundedRectangle(cornerRadius: 12)
          .fill(.thickMaterial)
          .overlay {
            //Music Info
            MusicInfo(expandPlayer: $expandPlayer, animation: animation)
          }
          .matchedGeometryEffect(id: "Background", in: animation)
      }
    }
    .frame(width: 370, height: 58)
    .offset(y: -49)
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
