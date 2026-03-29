import Foundation
import SwiftData

@Model
final class PlaylistImportCandidateEntry {
    @Attribute(.unique) var candidateID: String

    var trackEntryID: String

    var mediaID: String
    var title: String
    var artistName: String?
    var albumName: String?
    var artworkURLString: String?
    var durationSeconds: Double?

    var confidenceScore: Double
    var rank: Int

    init(
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