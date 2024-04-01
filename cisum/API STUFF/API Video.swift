//
//  API Video.swift
//  cisum
//
//  Created by Aarav Gupta on 31/03/2024.
//

import Foundation

// MARK: - PipedVideo
struct APIVideo: Codable, Identifiable {
    let id: String
    let title, uploader: String
    let thumbnailURL: String
    let audioStreams, videoStreams: [OStream]

    enum CodingKeys: String, CodingKey {
        case id, title, uploader
        case thumbnailURL = "thumbnailUrl"
        case audioStreams, videoStreams
    }
}


// MARK: - OStream
struct OStream: Codable {
    let url: String
    let videoOnly: Bool
}

// MARK: - APISearchResponse
struct APISearchResponse: Codable {
    let items: [VideoItem]
}

// MARK: - Item
struct VideoItem: Codable {
    let title: String
    let thumbnail: String
    let uploaderName: String
    let duration: Int
    let url: String // Directly using the URL here

    var videoId: String? {
        URLComponents(string: url)?.queryItems?.first(where: { $0.name == "v" })?.value
    }

    enum CodingKeys: String, CodingKey {
        case title, thumbnail, uploaderName, duration, url
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
