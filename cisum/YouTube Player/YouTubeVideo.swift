//
//  YouTubeVideo.swift
//  YouTubeExamples
//
//  Created by Mattycbtw on 26/03/2024.
//

import Foundation

struct YouTubeVideo: Identifiable, Codable {
    let id: String
    let title: String
    let thumbnailUrl: URL
    let audioUrl: URL?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title = "title"
        case thumbnailUrl = "thumbnailUrl"
        case audioUrl = "audioUrl"
    }
}

struct YouTubeSearchResponse: Codable {
    let items: [VideoItem]
}

struct VideoItem: Codable {
    let id: VideoID
    let snippet: VideoSnippet
}

struct VideoID: Codable {
    let kind: String
    let videoId: String?
    let channelId: String?
    let playlistId: String?

    enum CodingKeys: String, CodingKey {
        case kind, videoId, channelId, playlistId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.kind = try container.decode(String.self, forKey: .kind)
        self.videoId = try container.decodeIfPresent(String.self, forKey: .videoId)
        self.channelId = try container.decodeIfPresent(String.self, forKey: .channelId)
        self.playlistId = try container.decodeIfPresent(String.self, forKey: .playlistId)
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
