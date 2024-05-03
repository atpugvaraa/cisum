//
//  Search.swift
//  cisum
//
//  Created by Aarav Gupta on 09/03/24.
//

import SwiftUI
import Foundation
import YouTubeResponder
import AVKit
import SDWebImageSwiftUI

struct SearchView: View {
  @State private var player: AVPlayer = AVPlayer()
  var keyword: String {"\(viewModel.artistName ?? "") \(viewModel.title ?? "")" }
  @State var isLoggedin: Bool = false
  var videoID: String
  let AccentColor = Color(red : 0.9764705882352941, green: 0.17647058823529413, blue: 0.2823529411764706)
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
  @StateObject private var searchViewModel = SearchViewModel()

  var body: some View {
    NavigationView {
      VStack {
        Picker("Filter", selection: $searchViewModel.filter) {
          ForEach(MediaFilter.allCases, id: \.self) { filter in
            Text(filter.rawValue)
          }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal)
        .padding(.vertical, 5)
        .clipped()

        if searchViewModel.isLoading {
          ProgressView()
        } else if searchViewModel.videos.isEmpty && !searchViewModel.searchText.isEmpty {
          Text("Please search for \"\(searchViewModel.searchText)\" again.")
            .padding()
        } else {
          listContent
        }
      }
      .safeAreaInset(edge: .bottom) {
        FloatingPlayer()
      }
      .overlay {
        if expandPlayer {
          Player(animation: animation, expandPlayer: $expandPlayer, videoID: viewModel.videoID ?? videoID)
            .transition(.asymmetric(insertion: .identity, removal: .offset(y: -5)))
        }
      }
      .toolbar(expandPlayer ? .hidden : .visible, for: .navigationBar)
      .toolbar(expandPlayer ? .hidden : .visible, for: .tabBar)
      .searchable(text: $searchViewModel.searchText)
      .navigationTitle("Search")
      .navigationBarTitleDisplayMode(.automatic)
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

  private var loadingView: some View {
    ProgressView("Loading...")
      .progressViewStyle(.circular)
      .padding()
  }

  private var emptyStateView: some View {
    Text("Please search for \"\(searchViewModel.searchText)\" again.")
      .padding()
      .foregroundColor(.gray)
  }

  private var listContent: some View {
    ScrollView {
      LazyVGrid(columns: Array(repeating: GridItem(spacing: 6), count: 2), spacing: 6) {
        ForEach(searchViewModel.videos) { video in
          videoColumn(for: video)
        }
      }
      .padding(.horizontal)
    }
  }

  private func videoColumn(for video: VideoResponse) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      videoThumbnail(for: video)
        .frame(width: 171.5, height: 171.5)

      Text(video.title)
        .font(.caption)
        .foregroundColor(.primary)
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .center)
    }
    .onTapGesture {
      updateCurrentVideo(to: video)
      UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
      expandPlayer = true
    }
    .frame(width: 171.5, height: 200, alignment: .leading)
    .padding(.vertical, 4)
  }

  private func updateCurrentVideo(to video: VideoResponse) {
    viewModel.videoID = video.id
    viewModel.title = video.title
    viewModel.duration = video.duration
    viewModel.artistName = video.artistName
    viewModel.thumbnailURL = video.thumbnailURL
    viewModel.expandPlayer = true
  }

  private func videoThumbnail(for video: VideoResponse) -> some View {
    WebImage(url: URL(string: video.thumbnailURL)) { phase in
      switch phase {
      case .empty:
        ProgressView()
      case .success(let image):
        image.resizable()
          .interpolation(.high)
          .aspectRatio(contentMode: .fill)
          .frame(width: 171.5, height: 171.5)
          .clipShape(RoundedRectangle(cornerRadius: 12))
          .matchedGeometryEffect(id: video.id, in: animation)
      case .failure:
        Image(systemName: "musicnote")
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(width: 171.5, height: 171.5)
          .clipShape(RoundedRectangle(cornerRadius: 12))
      }
    }
  }
}

struct AlertMessage: Identifiable {
  let id = UUID() // Automatically provides a unique identifier
  let message: String
}

enum MediaFilter: String, CaseIterable {
  case song = "Songs"
  case video = "Music Videos"
  case artist = "Artist"
}
