//
//  API Video.swift
//  cisum
//
//  Created by Aarav Gupta on 31/03/2024.
//

import Foundation

struct APIVideo: Codable, Identifiable {
    let id: String
    let title: String
    let thumbnailURL: String

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case thumbnailURL = "thumbnailUrl"
    }
}

// MARK: - APISearchResponse
struct APISearchResponse: Codable {
    let items: [VideoItem]
}

// MARK: - VideoItem
struct VideoItem: Codable {
    let title: String
    let thumbnail: String
    let duration: Int
    let url: String

    var videoId: String? {
        guard let components = URLComponents(string: url),
              let queryItem = components.queryItems?.first(where: { $0.name == "v" }),
              let videoId = queryItem.value
        else {
            print("Failed to extract videoId from URL: \(url)")
            return nil
        }
        return videoId
    }

    enum CodingKeys: String, CodingKey {
        case title, thumbnail, duration, url
    }
}

struct VideoID: Codable {
    let kind: String
    let videoId: String?
    let channelId: String?
    let playlistId: String?
    let url: String

    enum CodingKeys: String, CodingKey {
        case kind, videoId, channelId, playlistId, url
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.kind = try container.decode(String.self, forKey: .kind)
        self.videoId = try container.decodeIfPresent(String.self, forKey: .videoId)
        self.channelId = try container.decodeIfPresent(String.self, forKey: .channelId)
        self.playlistId = try container.decodeIfPresent(String.self, forKey: .playlistId)
        self.url = try container.decode(String.self, forKey: .url)
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
