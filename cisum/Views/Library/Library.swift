//
//  Library.swift
//  cisum
//
//  Created by Aarav Gupta on 09/03/24.
//

import SwiftUI

struct Library: View {
  //Miscellaneous
  let AccentColor = Color(red : 0.9764705882352941, green: 0.17647058823529413, blue: 0.2823529411764706)
  let accentColor = Color(red: 0.976, green: 0.176, blue: 0.282, opacity: 0.3)

  //Animation Properties
  @EnvironmentObject var viewModel: PlayerViewModel
    @StateObject var mainViewModel = MainViewModel()
  @Namespace var animation
  @State var expandPlayer: Bool = false

  //Side Menu Properties
  var sideMenuWidth: CGFloat = 180
  @State private var showMenu: Bool = false
  @State private var offsetX: CGFloat = 0
  @State private var lastOffsetX: CGFloat = 0
  @State private var progress: CGFloat = 0
    @StateObject var profileViewModel = ProfileViewModel()
    private var currentUser: User? {
        return profileViewModel.currentUser
    }

  var body: some View {
    NavigationStack {
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
      } menuView: { _ in
          GeometryReader {
              let safeArea = $0.safeAreaInsets
              
              VStack(alignment: .leading, spacing: 12) {
                Text("cisum")
                  .font(.largeTitle.bold())
                  .padding(.bottom, 10)
                  NavigationLink(
                      destination: CurrentUserProfile(), label: {
                      HStack(spacing: 12) {
                          ProfileImage(user: currentUser, size: .sidemenu)
                          .padding(.vertical, 8)
                          .padding(.leading)

                        Text(currentUser?.username ?? "Profile")
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
                  
                  NavigationLink(
                      destination: Downloads(), label: {
                      HStack(spacing: 12) {
                          Image(systemName: "arrow.down.circle")
                          .padding(.vertical, 8)
                          .padding(.leading)
                          .font(.title3)

                        Text("Downloads")
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

                  NavigationLink(
                      destination: Settings(), label: {
                      HStack(spacing: 12) {
                          Image(systemName: "gear")
                          .padding(.vertical, 8)
                          .padding(.leading)
                          .font(.title3)

                        Text("Settings")
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
                  
                Spacer()

                VStack(spacing: 21) {
                  Button {
                      AuthService.shared.signOut()
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
                .padding(.bottom, 115)
              }
              .padding(.horizontal, 15)
              .padding(.vertical, 20)
              .padding(.top, safeArea.top)
              .padding(.bottom, safeArea.bottom)
              .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
              .environment(\.colorScheme, .dark)
            }
      } background: {
        Rectangle()
          .fill(.sideMenu)
      }
      .accentColor(AccentColor)
      .safeAreaInset(edge: .bottom) {
        FloatingPlayer()
      }
      .overlay {
          if expandPlayer {
              Player(animation: animation, expandPlayer: $expandPlayer, videoID: viewModel.videoID ?? mainViewModel.videoID)
                .transition(.asymmetric(insertion: .identity, removal: .offset(y: -5)))
          }
      }
      .toolbar(expandPlayer ? .hidden : .visible, for: .navigationBar)
      .toolbar(expandPlayer ? .hidden : .visible, for: .tabBar)
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
            if let user = currentUser {
                ProfileImage(user: user, size: .small)
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
            MusicInfo(title: viewModel.title ?? "Not Playing", artistName: viewModel.artistName ?? "", thumbnailURL: viewModel.thumbnailURL ?? "musicnote", animation: animation, expandPlayer: $expandPlayer)
          }
          .matchedGeometryEffect(id: "Background", in: animation)
      }
    }
    .offset(y: -10.5)
    .frame(width: 370, height: 58)
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
