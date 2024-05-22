//
//  ViewModels.swift
//  cisum
//
//  Created by Aarav Gupta on 29/04/24.
//

import SwiftUI
import Foundation
import Combine

class PlayerViewModel: ObservableObject {
  @Published var videoID: String?
  @Published var duration: Int?
  @Published var expandPlayer: Bool = false
  @Published var title: String? = nil
  @Published var artistName: String? = nil
  @Published var thumbnailURL: String? = nil
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
      videos = []
      artists = []
      isLoading = false
      return
    }

    isLoading = true
    let mediaType: APIService.MediaType
    switch filter {
    case .song:
      mediaType = .songs
    case .video:
      mediaType = .videos
    case .artist:
      mediaType = .artists
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
