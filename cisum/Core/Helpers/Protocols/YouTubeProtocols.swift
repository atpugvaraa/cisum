//
//  YouTubeProtocols.swift
//  cisum
//
//  Created by Aarav Gupta on 13/03/26.
//

import Foundation
import YouTubeSDK
import AVKit

protocol MusicSearchProvider {
    func search(_ query: String) async throws -> [YouTubeMusicSong]
}

protocol VideoSearchProvider {
    func search(_ query: String) async throws -> [YouTubeSearchResult]
}

protocol StreamingPlayer {
    var player: AVPlayer { get }
    func load(videoId: String, preferAudio: Bool) async throws
}
