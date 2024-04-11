//
//  Main.swift
//  cisum
//
//  Created by Aarav Gupta on 09/03/24.
//

import SwiftUI

struct Main: View {
  @State var isLoggedin: Bool = false
  var videoID: String
  let AccentColor = Color(red : 0.9764705882352941, green: 0.17647058823529413, blue: 0.2823529411764706)
  let accentColor = Color(red: 0.976, green: 0.176, blue: 0.282, opacity: 0.3)
  @State private var selectedTab = 0
  //Side Menu Properties
  var sideMenuWidth: CGFloat = 200
  @State private var offsetX: CGFloat = 0
  @State private var lastOffsetX: CGFloat = 0
  @State private var progress: CGFloat = 0
  //Animation Properties
  @State private var animateContent: Bool = false
  @State var expandPlayer: Bool = false
  @Namespace var animation
  @State private var showMenu: Bool = false
  @EnvironmentObject var viewModel: PlayerViewModel
  @State var image: UIImage?

  var body: some View {
    NavigationView {
      AnimatedSideBar(
        rotatesWhenExpanded: true,
        disablesInteraction: true,
        sideMenuWidth: 180,
        cornerRadius: 25,
        showMenu: $showMenu
      ) { safeArea in
        //MARK: Tab View
        TabView(selection: $selectedTab) {
          //Tabs
          Home(videoID: videoID)
            .tabItem {
              if selectedTab == 0 {
                Image("home.fill")
              } else {
                Image("home")
              }
              Text("Home")
            }
            .tag(0)

          Library(videoID: videoID)
            .tabItem {
              Image(systemName: "play.square.stack")
              Text("Library")
            }
            .tag(1)

          SearchView(videoID: videoID, expandPlayer: expandPlayer)
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
    }
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

      Spacer()

      VStack(spacing: 21) {
        NavigationLink(destination: LoginSignup(), label: {
          HStack(spacing: 12) {
            Image(systemName: isLoggedin ? "person.crop.circle.badge.plus" : "person.crop.circle")
              .padding(.vertical, 8)
              .padding(.leading)
              .font(.title3)
            Text(isLoggedin ? "Login" : "Sign up")
              .padding(.vertical, 8)
              .padding(.trailing)
              .font(.callout)
          }
          .background(
            RoundedRectangle(cornerRadius: 12)
              .foregroundColor(accentColor)
          )
        })

        Button {

        } label: {
          HStack(spacing: 12) {
            Image(systemName: "rectangle.portrait.and.arrow.right")
              .padding(.vertical, 8)
              .padding(.leading)
              .font(.title3)
            Text("Logout")
              .padding(.vertical, 8)
              .padding(.trailing)
              .font(.callout)
          }
          .background(
            RoundedRectangle(cornerRadius: 12)
              .foregroundColor(accentColor)
          )
        }
      }
      .padding(.bottom, 50)
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
    NavigationLink(
      destination: tab.view, label: {
        HStack(spacing: 12) {
          Image(systemName: tab.rawValue)
            .padding(.vertical, 8)
            .padding(.leading)
            .font(.title3)

          Text(tab.title)
            .padding(.vertical, 8)
            .padding(.trailing)
            .font(.callout)
        }
        .background(
          RoundedRectangle(cornerRadius: 12)
            .foregroundColor(accentColor)
        )
        .padding(.vertical, 10)
        .contentShape(.rect)
        .foregroundColor(AccentColor)
      })
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
}

#Preview {
  Main(videoID: "")
    .preferredColorScheme(.dark)
}
