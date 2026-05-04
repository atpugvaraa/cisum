//
//  Album.swift
//  Models
//
//  Created by Aarav Gupta on 29/04/26.
//

import Foundation
import SwiftData

@Model
public final class Album {
    @Attribute(.unique) public var albumID: String

    public var title: String
    public var normalizedTitle: String
    public var primaryArtistName: String?
    public var primaryArtistID: String?
    public var artworkURLString: String?
    public var releaseDateString: String?
    public var totalTracks: Int?

    public var spotifyAlbumID: String?
    public var spotifyAlbumURI: String?
    public var youtubePlaylistID: String?
    public var appleMusicAlbumID: String?

    public var createdAt: Date
    public var updatedAt: Date

    public init(
        albumID: String = UUID().uuidString,
        title: String,
        normalizedTitle: String,
        primaryArtistName: String? = nil,
        primaryArtistID: String? = nil,
        artworkURLString: String? = nil,
        releaseDateString: String? = nil,
        totalTracks: Int? = nil,
        spotifyAlbumID: String? = nil,
        spotifyAlbumURI: String? = nil,
        youtubePlaylistID: String? = nil,
        appleMusicAlbumID: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.albumID = albumID
        self.title = title
        self.normalizedTitle = normalizedTitle
        self.primaryArtistName = primaryArtistName
        self.primaryArtistID = primaryArtistID
        self.artworkURLString = artworkURLString
        self.releaseDateString = releaseDateString
        self.totalTracks = totalTracks
        self.spotifyAlbumID = spotifyAlbumID
        self.spotifyAlbumURI = spotifyAlbumURI
        self.youtubePlaylistID = youtubePlaylistID
        self.appleMusicAlbumID = appleMusicAlbumID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
