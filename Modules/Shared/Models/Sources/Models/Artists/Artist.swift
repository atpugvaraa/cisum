//
//  Artist.swift
//  Models
//
//  Created by Aarav Gupta on 29/04/26.
//

import Foundation
import SwiftData

@Model
public final class Artist {
    @Attribute(.unique) public var artistID: String

    public var displayName: String
    public var normalizedName: String
    public var artworkURLString: String?
    public var genresJSONString: String?

    public var spotifyArtistID: String?
    public var spotifyArtistURI: String?
    public var youtubeChannelID: String?
    public var youtubeMusicBrowseID: String?
    public var appleMusicArtistID: String?

    public var createdAt: Date
    public var updatedAt: Date

    public init(
        artistID: String = UUID().uuidString,
        displayName: String,
        normalizedName: String,
        artworkURLString: String? = nil,
        genresJSONString: String? = nil,
        spotifyArtistID: String? = nil,
        spotifyArtistURI: String? = nil,
        youtubeChannelID: String? = nil,
        youtubeMusicBrowseID: String? = nil,
        appleMusicArtistID: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.artistID = artistID
        self.displayName = displayName
        self.normalizedName = normalizedName
        self.artworkURLString = artworkURLString
        self.genresJSONString = genresJSONString
        self.spotifyArtistID = spotifyArtistID
        self.spotifyArtistURI = spotifyArtistURI
        self.youtubeChannelID = youtubeChannelID
        self.youtubeMusicBrowseID = youtubeMusicBrowseID
        self.appleMusicArtistID = appleMusicArtistID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
