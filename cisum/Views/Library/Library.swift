//
//  Library.swift
//  cisum
//
//  Created by Aarav Gupta on 09/03/24.
//

import SwiftUI

struct Library: View {
  @State var isLoggedin: Bool = false
  var videoID: String
  let AccentColor = Color(red : 0.9764705882352941, green: 0.17647058823529413, blue: 0.2823529411764706)
  let accentColor = Color(red : 0.976, green: 0.176, blue: 0.282, opacity: 0.3)
  @State private var selectedTab = 0
  //Side Menu Properties
  var sideMenuWidth: CGFloat = 180
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
        VStack {
          HStack(alignment: .center) {
            VStack(alignment: .leading) {
              Text("Library")
                .fontWeight(.bold)
                .font(.largeTitle)
            }
            Spacer()
          }
          .padding(.top, 90)
          .padding(.leading)

          List {
            // MARK: - Playlists

            NavigationLink(destination: {
              Playlists()
            }, label: {
              Label("Playlists", systemImage: "music.note.list")
            })
            .padding(.vertical, 8)

            // MARK: - Artists
            NavigationLink(destination: {
              Artists()
            }, label: {
              Label("Artist", systemImage: "music.mic")
            })
            .padding(.vertical, 8)

            // MARK: - Albums
            NavigationLink(destination: {
              Albums()
            }, label: {
              Label("Album", systemImage: "square.stack")
            })
            .padding(.vertical, 8)

            // MARK: - Downloaded
            NavigationLink(destination: {
              Downloads()
            }, label: {
              Label("Downloads", systemImage: "arrow.down.circle")
            })
            .padding(.vertical, 8)

            HStack(alignment: .center) {
              Button(action: {},
                     label: { Text("Recently Added") })
              Spacer()
            }.font(.title2)
              .bold()
              .foregroundColor(.primary)

            RecentlyAdded()

          }
          .listStyle(.plain)
          .scrollIndicators(.hidden)
          .navigationBarItems(trailing: EditButton())
          .accentColor(AccentColor)
        }
        .background(Color.black)
      } menuView: { safeArea in
        sideMenuView(safeArea)
      } background: {
        Rectangle()
          .fill(.sideMenu)
      }
      .accentColor(AccentColor)
      .safeAreaInset(edge: .bottom) {
        FloatingPlayer()
      }
      .overlay {
        Group {
          if viewModel.expandPlayer {
            ZStack {
              // Use UltraThickMaterial as the background
              RoundedRectangle(cornerRadius: animateContent ? deviceCornerRadius : 0, style: .continuous)
                .fill(.ultraThickMaterial)
                .overlay(content: {
                  RoundedRectangle(cornerRadius: animateContent ? deviceCornerRadius : 0, style: .continuous)
                    .fill(.ultraThickMaterial)
                    .opacity(animateContent ? 1 : 0)
                })
                .overlay(alignment: .top) {
                  MusicInfo(
                    expandPlayer: $viewModel.expandPlayer,
                    animation: animation,
                    currentTitle: viewModel.currentTitle ?? "Not Playing",
                    currentArtist: viewModel.currentArtist ?? "",
                    currentThumbnailURL: viewModel.currentThumbnailURL ?? "musicnote"
                  )
                  .allowsHitTesting(false)
                  .opacity(animateContent ? 0 : 1)
                }
                .matchedGeometryEffect(id: "Background", in: animation, isSource: false)
                .edgesIgnoringSafeArea(.all)
              // Your Player view
              Player(videoID: videoID, animation: animation, currentThumbnailURL: viewModel.currentThumbnailURL ?? "musicnote")
                .transition(.asymmetric(insertion: .move(edge: .bottom), removal: .move(edge: .bottom)))
            }
            .transition(.asymmetric(insertion: .move(edge: .bottom), removal: .move(edge: .bottom)))
          }
        }
      }
      .toolbar(viewModel.expandPlayer ? .hidden : .visible, for: .navigationBar)
      .toolbar(viewModel.expandPlayer ? .hidden : .visible, for: .tabBar)
      .navigationBarTitleDisplayMode(.automatic)
      .navigationBarLargeTitleItems(visible: showMenu ? false : true) {
        Button(action: {

          withAnimation(.snappy(duration: 0.3, extraBounce: 0)) {

            showMenu.toggle()


            if showMenu {
              showSideBar()
            } else {
              reset()
            }
          }
        }, label: {

          if let image = self.image {
            Image(uiImage: image)
              .resizable()
              .frame(width: 40, height: 40)
              .clipShape(Circle())
          } else {
            Image(systemName: "person.crop.circle")
              .font(.system(size: 30))
              .foregroundColor(AccentColor)
          }
        })
        .padding(.trailing)
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
            MusicInfo(expandPlayer: $viewModel.expandPlayer, animation: animation, currentTitle: viewModel.currentTitle ?? "Not Playing", currentArtist: viewModel.currentArtist ?? "", currentThumbnailURL: viewModel.currentThumbnailURL ?? "musicnote")
          }
          .matchedGeometryEffect(id: "Background", in: animation)
      }
    }
    .offset(y: -10.5)
    .frame(width: 370, height: 58)
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
      .padding(.bottom, 105)
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
}

struct RecentlyAdded: View {
  var body: some View {
    ScrollView(.vertical,showsIndicators: false)
    {
      VStack{
        // MARK: - Firt column
        HStack{

          HorizontalScollBottomCard( imageName: "Play-2", artistName: "Water - Single", SubartistName: "Tyla")

          HorizontalScollBottomCard( imageName: "Play-4", artistName: "Shazam", SubartistName: "Playlist")

        }
        HStack{
          HorizontalScollBottomCard( imageName: "Play-5", artistName: "Calm", SubartistName: "Playlist")

          HorizontalScollBottomCard( imageName: "Play-6", artistName: "Groove", SubartistName: "Mix")
        }
        HStack{
          HorizontalScollBottomCard( imageName: "Play-1", artistName: "Electric", SubartistName: "Mix")

          HorizontalScollBottomCard( imageName: "Play-3", artistName: "Made for you", SubartistName: "Curated Playlist")
        }
        HStack{

          HorizontalScollBottomCard( imageName: "Play-7", artistName: "Wave - Single", SubartistName: "CuBox")

          HorizontalScollBottomCard( imageName: "Play-8", artistName: "Drip Harder", SubartistName: "Mia")

        }
        HStack{

          HorizontalScollBottomCard( imageName: "Play-9", artistName: "Groove", SubartistName: "Swift")

          HorizontalScollBottomCard( imageName: "Play-10", artistName: "The Underground", SubartistName: "Darshan Raval")

        }
      }
    }
  }
}
