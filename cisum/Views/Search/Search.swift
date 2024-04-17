//
//  Search.swift
//  cisum
//
//  Created by Aarav Gupta on 09/03/24.
//

import SwiftUI
import Foundation
import Combine
import SDWebImageSwiftUI

class SearchViewModel: ObservableObject {
    @Published var videos = [APIVideo]()
    @Published var isLoading = false
    @Published var errorMessage: AlertMessage?
    @Published var searchText = "" {
        didSet {
            searchVideos()
        }
    }
    private var cancellables = Set<AnyCancellable>()

    init() {
        $searchText
            .removeDuplicates()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] searchText in
                self?.searchVideos(searchText: searchText)
            }
            .store(in: &cancellables)
    }

    private func searchVideos(searchText: String = "") {
      guard !searchText.isEmpty else {
        videos = []
//        errorMessage = AlertMessage(message: "Please enter a search term.")
          return
      }

    isLoading = true
      APIService().fetchVideos(query: searchText) { fetchedVideos in
          DispatchQueue.main.async {
            self.isLoading = false
              if fetchedVideos.isEmpty {
//                self.errorMessage = AlertMessage(message: "No videos found for \"\(searchText)\".")
              } else {
                self.videos = fetchedVideos
              }
          }
      }
    }
}

struct AlertMessage: Identifiable {
    let id = UUID() // Automatically provides a unique identifier
    let message: String
}

struct SearchView: View {
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
  @StateObject private var audioPlayerManager = AudioPlayerManager()
  private let gridLayout = [
    GridItem(.flexible()),
    GridItem(.flexible())
  ]

  var body: some View {
    NavigationView {
      VStack {
        if searchViewModel.isLoading {
          ProgressView()
        } else if searchViewModel.videos.isEmpty && !searchViewModel.searchText.isEmpty {
          Text("Please search for \"\(searchViewModel.searchText)\" again.")
            .padding()
        } else {
          listContent
        }
      }
      .searchable(text: $searchViewModel.searchText)
      .alert(item: $searchViewModel.errorMessage) { errorMessage in
        Alert(title: Text("Error"), message: Text(errorMessage.message), dismissButton: .default(Text("OK")))}
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
            MusicInfo(expandPlayer: $viewModel.expandPlayer, animation: animation, currentTitle: viewModel.currentTitle ?? "Not Playing", currentArtist: viewModel.currentArtist ?? "", currentThumbnailURL: viewModel.currentThumbnailURL ?? "musicnote")
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
      LazyVGrid(columns: gridLayout, spacing: 6) {
        ForEach(searchViewModel.videos) { video in
          videoColumn(for: video)
        }
      }
      .padding(.horizontal)
    }
  }

  private func videoColumn(for video: APIVideo) -> some View {
    VStack(alignment: .leading, spacing: 4) {
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
    }
    .frame(width: 171.5, height: 200, alignment: .leading)
    .padding(.vertical, 4)
  }

  private func updateCurrentVideo(to video: APIVideo) {
    viewModel.currentVideoID = video.id
    viewModel.currentTitle = video.title
    viewModel.currentThumbnailURL = video.thumbnailUrl
    viewModel.expandPlayer = true
  }

  private func videoThumbnail(for video: APIVideo) -> some View {
    WebImage(url: URL(string: video.thumbnailUrl)) { phase in
      switch phase {
      case .empty:
        ProgressView()
      case .success(let image):
        image.resizable()
          .aspectRatio(contentMode: .fill)
          .frame(width: 171.5, height: 171.5)
          .clipShape(RoundedRectangle(cornerRadius: 12))
          .matchedGeometryEffect(id: video.id, in: animation)
      case .failure:
        Image(systemName: "musicnote")
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(width: 171.5, height: 171.5)
          .clipShape(RoundedRectangle(cornerRadius: 8))
      }
    }
  }
}
