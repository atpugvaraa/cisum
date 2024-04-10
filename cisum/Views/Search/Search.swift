//
//  Search.swift
//  cisum
//
//  Created by Aarav Gupta on 09/03/24.
//

import SwiftUI
import Foundation
import Combine

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
  @EnvironmentObject var viewModel: PlayerViewModel
  @StateObject private var searchViewModel = SearchViewModel()
  @StateObject private var audioPlayerManager = AudioPlayerManager()
  @Binding var expandPlayer: Bool
  @Namespace private var animation
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
      .navigationTitle("Search")
      .searchable(text: $searchViewModel.searchText)
      .alert(item: $searchViewModel.errorMessage) { errorMessage in
        Alert(title: Text("Error"), message: Text(errorMessage.message), dismissButton: .default(Text("OK")))
      }
    }
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
    viewModel.currentThumbnailURL = video.thumbnailURL
    viewModel.expandPlayer = true
  }

  private func videoThumbnail(for video: APIVideo) -> some View {
    AsyncImage(url: URL(string: video.thumbnailURL)) { phase in
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
      @unknown default:
        EmptyView()
      }
    }
  }
}
