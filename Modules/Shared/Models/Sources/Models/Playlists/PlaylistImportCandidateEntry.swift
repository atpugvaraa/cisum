import Foundation
import SwiftData

@Model
public final class PlaylistImportCandidateEntry {
    @Attribute(.unique) public var candidateID: String

    public var trackEntryID: String

    public var mediaID: String
    public var title: String
    public var artistName: String?
    public var albumName: String?
    public var artworkURLString: String?
    public var durationSeconds: Double?

    public var confidenceScore: Double
    public var rank: Int

    public init(
        candidateID: String = UUID().uuidString,
        trackEntryID: String,
        mediaID: String,
        title: String,
        artistName: String? = nil,
        albumName: String? = nil,
        artworkURLString: String? = nil,
        durationSeconds: Double? = nil,
        confidenceScore: Double,
        rank: Int
    ) {
        self.candidateID = candidateID
        self.trackEntryID = trackEntryID
        self.mediaID = mediaID
        self.title = title
        self.artistName = artistName
        self.albumName = albumName
        self.artworkURLString = artworkURLString
        self.durationSeconds = durationSeconds
        self.confidenceScore = confidenceScore
        self.rank = rank
    }
}
