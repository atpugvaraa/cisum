//
//  Lyrics API.swift
//  cisum
//
//  Created by Aarav Gupta on 23/04/24.
//

import Foundation

// MARK: - LyricsResponse
struct LyricsResponse: Codable {
    let id: Int
    let name, trackName, artistName, albumName: String
    let duration: Int
    let plainLyrics, syncedLyrics: String
}
