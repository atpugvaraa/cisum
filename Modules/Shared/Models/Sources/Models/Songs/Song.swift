//
//  Song.swift
//  Models
//
//  Created by Aarav Gupta on 29/04/26.
//

import Foundation
import SwiftData

@Model
public final class Song {
    @Attribute(.unique) public var songID: String

    public var title: String
    public var normalizedTitle: String
    public var primaryArtistName: String?
    public var primaryArtistID: String?
    public var albumTitle: String?
    public var albumID: String?
    public var durationSeconds: Double?
    public var artworkURLString: String?
    public var isExplicit: Bool

    public var providerFingerprint: String

    public var spotifyTrackID: String?
    public var spotifyTrackURI: String?
    public var spotifyPreviewURLString: String?

    public var youtubeVideoID: String?
    public var youtubeMusicVideoID: String?

    public var appleMusicSongID: String?

    public var preferredFallbackProviderRawValue: String?
    public var cachedFallbackMediaID: String?
    public var lastResolvedAt: Date?

    public var createdAt: Date
    public var updatedAt: Date

    public init(
        songID: String = UUID().uuidString,
        title: String,
        normalizedTitle: String,
        primaryArtistName: String? = nil,
        primaryArtistID: String? = nil,
        albumTitle: String? = nil,
        albumID: String? = nil,
        durationSeconds: Double? = nil,
        artworkURLString: String? = nil,
        isExplicit: Bool = false,
        providerFingerprint: String,
        spotifyTrackID: String? = nil,
        spotifyTrackURI: String? = nil,
        spotifyPreviewURLString: String? = nil,
        youtubeVideoID: String? = nil,
        youtubeMusicVideoID: String? = nil,
        appleMusicSongID: String? = nil,
        preferredFallbackProviderRawValue: String? = nil,
        cachedFallbackMediaID: String? = nil,
        lastResolvedAt: Date? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.songID = songID
        self.title = title
        self.normalizedTitle = normalizedTitle
        self.primaryArtistName = primaryArtistName
        self.primaryArtistID = primaryArtistID
        self.albumTitle = albumTitle
        self.albumID = albumID
        self.durationSeconds = durationSeconds
        self.artworkURLString = artworkURLString
        self.isExplicit = isExplicit
        self.providerFingerprint = providerFingerprint
        self.spotifyTrackID = spotifyTrackID
        self.spotifyTrackURI = spotifyTrackURI
        self.spotifyPreviewURLString = spotifyPreviewURLString
        self.youtubeVideoID = youtubeVideoID
        self.youtubeMusicVideoID = youtubeMusicVideoID
        self.appleMusicSongID = appleMusicSongID
        self.preferredFallbackProviderRawValue = preferredFallbackProviderRawValue
        self.cachedFallbackMediaID = cachedFallbackMediaID
        self.lastResolvedAt = lastResolvedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var preferredFallbackProvider: MediaProvider? {
        get {
            guard let rawValue = preferredFallbackProviderRawValue else { return nil }
            return MediaProvider(rawValue: rawValue)
        }
        set {
            preferredFallbackProviderRawValue = newValue?.rawValue
        }
    }
}
