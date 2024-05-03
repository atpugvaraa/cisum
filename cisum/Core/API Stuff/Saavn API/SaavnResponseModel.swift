//
//  Saavn Model.swift
//  cisum
//
//  Created by Aarav Gupta on 23/04/24.
//

import Foundation

// MARK: - SaavnResponse
struct SaavnResponse: Codable {
    let success: Bool
    let data: DataClass
}

// MARK: - DataClass
struct DataClass: Codable {
    let topQuery: ArtistsResponse
    let songs: SongsResponse
    let albums: AlbumsResponse
    let artists: ArtistsResponse
    let playlists: PlaylistsResponse
}

// MARK: - Albums
struct AlbumsResponse: Codable {
    let results: [AlbumsResult]
    let position: Int
}

// MARK: - AlbumsResult
struct AlbumsResult: Codable {
    let id, title: String
    let image: [ImageResponse]
    let artist: String
    let url: String
    let type, description, year, songIDS: String
    let language: String

    enum CodingKeys: String, CodingKey {
        case id, title, image, artist, url, type, description, year
        case songIDS = "songIds"
        case language
    }
}

// MARK: - Image
struct ImageResponse: Codable {
    let quality: Quality
    let url: String
}

enum Quality: String, Codable {
    case img150X150 = "150x150"
    case img500X500 = "500x500"
    case img50X50 = "50x50"
}

// MARK: - Artists
struct ArtistsResponse: Codable {
    let results: [ArtistsResult]
    let position: Int
}

// MARK: - ArtistsResult
struct ArtistsResult: Codable {
    let id, title: String
    let image: [ImageResponse]
    let type, description: String
    let position: Int?
}

// MARK: - Playlists
struct PlaylistsResponse: Codable {
    let results: [PlaylistsResult]
    let position: Int
}

// MARK: - PlaylistsResult
struct PlaylistsResult: Codable {
    let id, title: String
    let image: [ImageResponse]
    let url: String
    let type, language, description: String
}

// MARK: - Songs
struct SongsResponse: Codable {
    let results: [SongsResult]
    let position: Int
}

// MARK: - SongsResult
struct SongsResult: Codable {
    let id, title: String
    let image: [ImageResponse]
    let album: String
    let url: String
    let type, description, primaryArtists, singers: String
    let language: String
}
