////
////  PipedVideo.swift
////  cisum
////
////  Created by Aarav Gupta on 01/04/24.
////
//
//import SwiftUI
//import Foundation
//
//struct PipedVideo: Codable {
//    let title, description: String
//    let uploadDate: Date
//    let uploader, uploaderURL: String
//    let uploaderAvatar, thumbnailURL, hls: String
//    let lbryID: JSONNull?
//    let category, license, visibility: String
//    let tags: [String]
//    let uploaderVerified: Bool
//    let duration, views, likes, dislikes, uploaderSubscriberCount: Int
//    let audioStreams, videoStreams: [OStream]
//    let relatedStreams: [RelatedStream]
//    let proxyURL: String
//    let previewFrames: [PreviewFrame]
//}
//
//struct OStream: Codable {
//    let url: String
//    let format: Format
//    let quality, mimeType: String
//    let codec: String?
//    let videoOnly: Bool
//    let itag, bitrate, initStart, initEnd, indexStart, indexEnd, width, height, fps, contentLength: Int
//}
//
//enum Format: String, Codable {
//    case m4A = "M4A", mpeg4 = "MPEG_4", webm = "WEBM", webmaOpus = "WEBMA_OPUS"
//}
//
//enum MIMEType: String, Codable {
//    case audioMp4 = "audio/mp4", audioWebm = "audio/webm", videoMp4 = "video/mp4", videoWebm = "video/webm"
//}
//
//struct PreviewFrame: Codable {
//    let urls: [String]
//    let frameWidth, frameHeight, totalCount, durationPerFrame, framesPerPageX, framesPerPageY: Int
//}
//
//struct RelatedStream: Codable {
//    let url, thumbnail, uploaderName: String
//    let uploaderURL: String?
//    let uploadedDate: String?
//    let uploaderAvatar: String?
//    let title: String?
//    let duration, views, uploaded: Int?
//    let uploaderVerified, isShort: Bool
//    let type: TypeEnum
//    let shortDescription: JSONNull?
//    let name, playlistType: String?
//    let videos: Int?
//}
//
//enum TypeEnum: String, Codable {
//    case playlist = "playlist", stream = "stream"
//}
//    
//
////struct YouTubeVideo: Identifiable, Codable {
////    let id: String
////    let title: String
////    let thumbnailUrl: URL
////    let audioUrl: URL?
////    
////    enum CodingKeys: String, CodingKey {
////        case id
////        case title = "title"
////        case thumbnailUrl = "thumbnailUrl"
////        case audioUrl = "audioUrl"
////    }
////}
////
////struct YouTubeSearchResponse: Codable {
////    let items: [VideoItem]
////}
////
////struct VideoItem: Codable {
////    let id: VideoID
////    let snippet: VideoSnippet
////}
////
////struct VideoID: Codable {
////    let kind: String
////    let videoId: String?
////    let channelId: String?
////    let playlistId: String?
////    
////    enum CodingKeys: String, CodingKey {
////        case kind, videoId, channelId, playlistId
////    }
////    
////    init(from decoder: Decoder) throws {
////        let container = try decoder.container(keyedBy: CodingKeys.self)
////        self.kind = try container.decode(String.self, forKey: .kind)
////        self.videoId = try container.decodeIfPresent(String.self, forKey: .videoId)
////        self.channelId = try container.decodeIfPresent(String.self, forKey: .channelId)
////        self.playlistId = try container.decodeIfPresent(String.self, forKey: .playlistId)
////    }
////}
////
////
////struct VideoSnippet: Codable {
////    let title: String
////    let thumbnails: ThumbnailContainer
////}
////
////struct ThumbnailContainer: Codable {
////    let medium: ThumbnailDetail
////}
////
////struct ThumbnailDetail: Codable {
////    let url: URL
////}
