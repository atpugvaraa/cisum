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

    // Ephemeral playback URL data MUST NOT be persisted here. Playback URLs are
    // ephemeral runtime artifacts and are stored in an in-memory TTL store.
    // Persist only minimal canonical metadata for playback resolution auditing.
    public var canonicalID: String?
    public var activeRepresentationKey: String?
    // Optional JSON blobs for hydration/candidate metadata; kept small and opaque.
    public var hydrationMetadataJSON: String?
    public var candidateMetadataJSON: String?
    public var playbackResolvedAt: Date?

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
