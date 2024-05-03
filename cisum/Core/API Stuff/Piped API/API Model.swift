//
//  Search Model.swift
//  cisum
//
//  Created by Aarav Gupta on 20/04/24.
//

import Foundation

// MARK: - VideoResponse
struct VideoResponse: Codable, Identifiable {
    let id: String
    let title: String
    let artistName: String
    let thumbnailURL: String
    let duration: Int

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case artistName = "uploader"
        case thumbnailURL = "thumbnailUrl"
        case duration
    }
}

// MARK: - SongItem
struct SongItem: Codable {
    let url: String
    let title: String
    let artistName: String
    let thumbnailURL: String
    let duration: Int

  var videoId: String? {
      guard let videoIdValue = URLComponents(string: url)?.queryItems?.first(where: { $0.name == "v" })?.value else {
          print("Failed to extract videoId from URL: \(url)")
          return nil
      }
      return videoIdValue
  }

    enum CodingKeys: String, CodingKey {
        case url, title, thumbnailURL = "thumbnail"
        case artistName = "uploaderName"
        case duration
    }
}

// MARK: - VideoItem
struct VideoItem: Codable {
    let url: String
    let title: String
    let artistName: String
    let thumbnailURL: String
    let duration: Int

  var videoId: String? {
      guard let videoIdValue = URLComponents(string: url)?.queryItems?.first(where: { $0.name == "v" })?.value else {
          print("Failed to extract videoId from URL: \(url)")
          return nil
      }
      return videoIdValue
  }

    enum CodingKeys: String, CodingKey {
        case url, title, thumbnailURL = "thumbnail"
        case artistName = "uploaderName"
        case duration
    }
}

struct VideoID: Codable {
    let videoId: String?
    let url: String

    private enum CodingKeys: String, CodingKey {
        case videoId, url
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.videoId = try container.decodeIfPresent(String.self, forKey: .videoId)
        self.url = try container.decode(String.self, forKey: .url)
    }
}

// MARK: - SongSearchResponse
struct SongSearchResponse: Codable {
    let items: [SongItem]
}

// MARK: - VideoSearchResponse
struct VideoSearchResponse: Codable {
    let items: [VideoItem]
}

// MARK: - ArtistResponse
struct ArtistResponse: Codable {
    let id, name: String
    let avatarURL: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case avatarURL = "avatarUrl"
    }
}

// MARK: - ArtistSearchResponse
struct ArtistSearchResponse: Codable {
    let items: [ArtistItem]
}

// MARK: - ArtistItem
struct ArtistItem: Codable {
    let url, name: String
    let thumbnail: String
    let artistId: String

    enum CodingKeys: String, CodingKey {
        case url, name, thumbnail
        case artistId = "channelID"
    }
}

struct ArtistID: Codable {
  var artistId: String?
    let url: String

    private enum CodingKeys: String, CodingKey {
        case artistId, url
    }

  // Implement custom decoding for artistId
  init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      self.url = try container.decode(String.self, forKey: .url)
      self.artistId = try container.decode(String.self, forKey: .artistId)

      // Parse the URL and get the path component
      if let urlComponents = URLComponents(string: url),
         let path = urlComponents.path.split(separator: "/").last {
          self.artistId = String(path)
      } else {
          self.artistId = nil
      }
  }
}

struct VideoSnippet: Codable {
    let title: String
    let thumbnails: ThumbnailContainer
}

struct ThumbnailContainer: Codable {
    let medium: ThumbnailDetail
}

struct ThumbnailDetail: Codable {
    let url: URL
}
