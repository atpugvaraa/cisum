//
//  ViewModels.swift
//  cisum
//
//  Created by Aarav Gupta on 29/04/24.
//

import Combine
import Firebase
import FirebaseFirestoreSwift
import Foundation

class MainViewModel: ObservableObject {
    @Published var videoID: String = ""
    @Published var title: String = ""
    @Published var thumbnailURL: String = ""
}

class PlayerViewModel: ObservableObject {
  @Published var videoID: String?
  @Published var duration: Int?
  @Published var expandPlayer: Bool = false
  @Published var title: String? = nil
  @Published var artistName: String? = nil
  @Published var thumbnailURL: String? = nil
}

class UserSearchViewModel: ObservableObject {
    @Published var users = [User]()
    
    init() {
        Task { try await fetchUsers() }
    }
    
    @MainActor
    private func fetchUsers() async throws {
        self.users = try await UserService.fetchUsers()
    }
}

class SearchViewModel: ObservableObject {
  @Published var videos = [VideoResponse]()
  @Published var artists = [ArtistResponse]()
  @Published var isLoading = false
  @Published var errorMessage: AlertMessage?
  @Published var filter: MediaFilter = .song
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
        artists = []
      videos = []
      isLoading = false
      return
    }

    isLoading = true
    let mediaType: APIService.MediaType
    switch filter {
    case .artist:
      mediaType = .artists
    case .song:
      mediaType = .songs
    case .video:
      mediaType = .videos
    }
    APIService().fetchMedia(query: searchText, mediaType: mediaType) { [weak self] fetchedVideos in
      DispatchQueue.main.async {
        self?.isLoading = false
            if fetchedVideos.isEmpty {
              print("empty")
            } else {
              self?.videos = fetchedVideos
            }
        }
    }

    APIService().fetchArtists(query: searchText, mediaType: .artists) { [weak self] fetchedArtists in
      DispatchQueue.main.async {
        self?.isLoading = false
        if fetchedArtists.isEmpty {
          print("empty")
        } else {
          self?.artists = fetchedArtists
        }
      }
    }
  }
}
