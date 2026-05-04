//
//  MediaCacheEntry.swift
//  Models
//
//  Created by Aarav Gupta on 29/04/26.
//

import Foundation
import SwiftData

@Model
public final class MediaCacheEntry {
    @Attribute(.unique) public var mediaID: String

    public var playbackPreferredURLString: String?
    public var playbackHLSURLString: String?
    public var playbackMuxedURLString: String?
    public var playbackAudioURLString: String?
    public var playbackAudioMimeType: String?
    public var playbackUpdatedAt: Date?
    public var playbackValidUntilAt: Date?

    public var artworkURLString: String?
    public var artworkUpdatedAt: Date?
    public var localArtworkFilename: String?
    public var localArtworkUpdatedAt: Date?

    public var motionArtworkHLSURLString: String?
    public var motionArtworkUpdatedAt: Date?

    public var lastAccessedAt: Date

    public init(mediaID: String, lastAccessedAt: Date = .now) {
        self.mediaID = mediaID
        self.lastAccessedAt = lastAccessedAt
    }
}
