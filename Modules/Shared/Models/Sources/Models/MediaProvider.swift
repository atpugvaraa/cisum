import Foundation
import SwiftData

public enum MediaProvider: String, Codable, CaseIterable, Sendable {
    // mainstream
    case youtube
    case youtubeMusic = "youtube_music"
    case appleMusic = "apple_music"
    case spotify
    case tidal
    case qobuz
    
    // others
    case kuwo
    case kugou
    case qqMusic = "qq_music"
    case tencentMusic = "tencent_music"
    case neteaseMusic = "netease_music"
}

public enum PlaylistSource: String, Codable, CaseIterable, Sendable {
    case youtube
    case youtubeMusic = "youtube_music"
    case spotify
    case appleMusic = "apple_music"
    case tidal
    case qobuz
    case unknown
}

