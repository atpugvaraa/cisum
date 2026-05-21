//
//  ListeningHistoryEntry.swift
//  Models
//
//  Created by Copilot.
//

import Foundation
import SwiftData

@Model
public final class ListeningHistoryEntry {
    public var mediaID: String
    public var title: String
    public var artist: String
    public var album: String?
    public var artworkURL: String?
    public var streamingService: String
    public var startedAt: Date
    public var endedAt: Date?
    public var listenedSeconds: Double
    public var wasScrobbled: Bool
    public var scrobbledAt: Date?

    public init(
        mediaID: String,
        title: String,
        artist: String,
        album: String? = nil,
        artworkURL: String? = nil,
        streamingService: String,
        startedAt: Date = .now,
        endedAt: Date? = nil,
        listenedSeconds: Double = 0,
        wasScrobbled: Bool = false,
        scrobbledAt: Date? = nil
    ) {
        self.mediaID = mediaID
        self.title = title
        self.artist = artist
        self.album = album
        self.artworkURL = artworkURL
        self.streamingService = streamingService
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.listenedSeconds = listenedSeconds
        self.wasScrobbled = wasScrobbled
        self.scrobbledAt = scrobbledAt
    }
}