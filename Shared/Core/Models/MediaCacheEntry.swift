import Foundation
import SwiftData

@Model
final class MediaCacheEntry {
    @Attribute(.unique) var mediaID: String

    var playbackPreferredURLString: String?
    var playbackHLSURLString: String?
    var playbackMuxedURLString: String?
    var playbackAudioURLString: String?
    var playbackAudioMimeType: String?
    var playbackUpdatedAt: Date?

    var artworkURL1500String: String?
    var artworkUpdatedAt: Date?
    var localArtworkFilename: String?
    var localArtworkUpdatedAt: Date?

    var motionArtworkHLSURLString: String?
    var motionArtworkUpdatedAt: Date?

    var lastAccessedAt: Date

    init(mediaID: String, lastAccessedAt: Date = .now) {
        self.mediaID = mediaID
        self.lastAccessedAt = lastAccessedAt
    }
}
