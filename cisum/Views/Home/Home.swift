//
//  Home.swift
//  cisum
//
//  Created by Aarav Gupta on 09/03/24.
//

import SwiftUI

struct Home: View {
  @State var isLoggedin: Bool = false
  var videoID: String
  let AccentColor = Color(red : 0.9764705882352941, green: 0.17647058823529413, blue: 0.2823529411764706)
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
      //MARK: Tab View
      ScrollView(.vertical , showsIndicators: false) {
        HStack(alignment: .center,spacing: 0 ,content: {
          Text("Top Picks")
            .fontWeight(.bold)
            .font(.title3)
          Spacer()
        })
        .frame(height: 24)
        .padding(.leading)

        TopPicksScroll()
          .padding(.bottom)

        HStack(alignment:.center){
          Text("Recently Played")
          Spacer()
        }.padding(.leading)
          .font(.title3)
          .bold()
          .foregroundColor(.primary)

        Recents()

        HStack(alignment:.center){
          Text("Try something else")
          Spacer()
        }
        .padding(.leading)
        .font(.title3)
        .bold()
        .foregroundColor(.primary)

        HorizontalScrollBottom2()

        HStack(alignment:.center){
          Text("Made For You")
          Spacer()
        }
        .padding(.leading)
        .font(.title3)
        .bold()
        .foregroundColor(.primary)

        TopPicksScroll().padding(.bottom)
      }
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
      .navigationTitle("Home")
      .navigationBarTitleDisplayMode(.automatic)
      .navigationBarLargeTitleItems(visible: true) {
        self.sideMenuButton
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
    .frame(width: 370, height: 58)
  }

  //MARK: SideMenuButton
  var sideMenuButton: some View {
    Button(action: {
      withAnimation(.snappy(duration: 0.3, extraBounce: 0)) {
        if showMenu {
          reset()
        } else {
          showSideBar()
        }
      }
    }, label: {
      if let image = self.image {
        Image(uiImage: image)
          .resizable()
          .frame(width: 40, height: 40)
          .clipShape(RoundedRectangle(cornerRadius: 25.0))
      } else {
        Image(systemName: "person.crop.circle")
          .font(.system(size: 40))
          .foregroundColor(AccentColor)
      }
    })
    .padding(.bottom, -10)
    .padding(.trailing)
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

struct TopPicksScroll: View {
  var body: some View {
    ScrollView(.horizontal) {
      HStack(spacing: 6) {
        TopPicksCard(
          headLine: "Drake mix",
          imageName: "Image",
          artistName: "Drake, J. Cole, Halsey",
          colorBlock: .blue
        )
        .padding(.leading)

        TopPicksCard(
          headLine: "Featuring you",
          imageName: "Image",
          artistName: "Artist A, Artist B, Artist C",
          colorBlock: .brown
        )

        TopPicksCard(
          headLine: "Custom Headline 2",
          imageName: "Image",
          artistName: "Artist X, Artist Y, Artist Z",
          colorBlock: .red
        )

        TopPicksCard(
          headLine: "Custom Headline 3",
          imageName: "Image",
          artistName: "Custom Artist 1, Custom Artist 2, Custom Artist 3",
          colorBlock: .pink
        )
      }
    }
    .scrollIndicators(.hidden)
  }
}

struct TopPicksCard: View {

  let headLine: String
  let imageName: String
  let artistName: String
  let colorBlock: Color

  var body: some View {
    VStack {
      HStack {
        Text(headLine).font(.caption).foregroundColor(.gray)
          .padding(.leading, -1)
        Spacer()
      }.frame(width: 260)
      ZStack {
        Rectangle()
          .foregroundStyle(colorBlock.gradient).opacity(0.6)
          .frame(width: 260,height: 346)

        VStack {
          Image(imageName)
            .resizable()
            .scaledToFit()
            .frame(width: 260 ,height: 260)
          Spacer()

          Text(artistName)
            .font(.subheadline)
            .foregroundStyle(Color.white)
            .multilineTextAlignment(.center)
            .padding([.trailing ,.leading])
          Spacer()

        }.frame(width: 260,height: 346)
      }.cornerRadius(10)
    }
  }
}

struct Recents: View {
  var body: some View {
    ScrollView(.horizontal ,showsIndicators: false){
      HStack {
        HorizontalScollBottomCard( imageName: "Image", artistName: "Tame Impala", SubartistName: "Artist")
          .padding(.leading)
        HorizontalScollBottomCard( imageName: "Image", artistName: "The Beatles", SubartistName: "Music Rock")
        HorizontalScollBottomCard( imageName: "Image", artistName: "Frank Ocean", SubartistName: "Music")
        HorizontalScollBottomCard( imageName: "Image", artistName: "Halsey", SubartistName: "")
        HorizontalScollBottomCard( imageName: "Image", artistName: "bro", SubartistName: "Music")
      }

    }
  }
}

struct HorizontalScollBottomCard: View {

  let imageName: String
  let artistName: String
  let SubartistName: String?


  var body: some View {
    VStack(alignment: .leading) {
      Image(imageName)
        .resizable()
        .scaledToFit()
        .frame(width: 170  ,height: 170)
        .cornerRadius(10)

      VStack(alignment: .leading) {
        Text(artistName)
          .font(.caption)
          .foregroundStyle(Color.primary)

        Text(SubartistName ?? "")
          .font(.caption)
          .foregroundStyle(Color.gray)
      }.padding(.leading ,10)
    }.frame(width: 170,height: 215)
  }
}

struct HorizontalScrollBottom2: View {
  var body: some View {
    ScrollView(.horizontal ,showsIndicators: false){
      HStack {
        HorizontalScollBottomCard( imageName: "Image", artistName: "Today's Hits", SubartistName: "Music Hits")
          .padding(.leading)

        HorizontalScollBottomCard( imageName: "Image", artistName: "Verified Hits", SubartistName: "Music Pop")

        HorizontalScollBottomCard( imageName: "Image", artistName: "Pure Focus", SubartistName: "Music Alternative")

        HorizontalScollBottomCard( imageName: "Image", artistName: "Everday Jam", SubartistName: "Music Dance")

        HorizontalScollBottomCard( imageName: "Image", artistName: "Pure Focus", SubartistName: "Music Alternative")

        HorizontalScollBottomCard( imageName: "Image", artistName: "Today's Hits", SubartistName: "Music Hits")

        HorizontalScollBottomCard( imageName: "Image", artistName: "Everday Jam", SubartistName: "Music Dance")

        HorizontalScollBottomCard( imageName: "Image", artistName: "Verified Hits", SubartistName: "Music Pop")
      }
    }
  }
}
