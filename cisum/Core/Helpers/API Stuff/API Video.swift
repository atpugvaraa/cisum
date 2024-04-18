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

struct APISearchResponse: Codable {
    let items: [VideoItem]
}

struct VideoItem: Codable {
    let title: String
    let thumbnail: String
    let duration: Int
    let url: String

    var videoId: String? {
        guard let videoIdValue = URLComponents(string: url)?.queryItems?.first(where: { $0.name == "v" })?.value else {
            print("Failed to extract videoId from URL: \(url)")
            return nil
        }
        return videoIdValue
    }

    private enum CodingKeys: String, CodingKey {
        case title, thumbnail, duration, url
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
