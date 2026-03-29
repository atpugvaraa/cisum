import Foundation
import SwiftData

enum PlaylistItemImportStatus: String, Codable, CaseIterable, Sendable {
    case pending
    case matched
    case uncertain
    case failed
    case skipped
}

@Model
final class PlaylistItem {
    @Attribute(.unique) var itemKey: String

    var playlistID: String
    var sortIndex: Int

    var sourceTrackID: String?
    var sourceTrackFingerprint: String

    var title: String
    var artistName: String?
    var albumName: String?
    var durationSeconds: Double?
    var artworkURLString: String?

    var resolvedMediaID: String?
    var resolutionConfidence: Double?

    var importStatusRawValue: String
    var importErrorCode: String?
    var importErrorMessage: String?

    var createdAt: Date
    var updatedAt: Date

    init(
        playlistID: String,
        sortIndex: Int,
        sourceTrackID: String? = nil,
        sourceTrackFingerprint: String,
        title: String,
        artistName: String? = nil,
        albumName: String? = nil,
        durationSeconds: Double? = nil,
        artworkURLString: String? = nil,
        resolvedMediaID: String? = nil,
        resolutionConfidence: Double? = nil,
        importStatus: PlaylistItemImportStatus = .pending,
        importErrorCode: String? = nil,
        importErrorMessage: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.itemKey = Self.makeItemKey(playlistID: playlistID, sortIndex: sortIndex)
        self.playlistID = playlistID
        self.sortIndex = sortIndex
        self.sourceTrackID = sourceTrackID
        self.sourceTrackFingerprint = sourceTrackFingerprint
        self.title = title
        self.artistName = artistName
        self.albumName = albumName
        self.durationSeconds = durationSeconds
        self.artworkURLString = artworkURLString
        self.resolvedMediaID = resolvedMediaID
        self.resolutionConfidence = resolutionConfidence
        self.importStatusRawValue = importStatus.rawValue
        self.importErrorCode = importErrorCode
        self.importErrorMessage = importErrorMessage
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var importStatus: PlaylistItemImportStatus {
        get { PlaylistItemImportStatus(rawValue: importStatusRawValue) ?? .pending }
        set { importStatusRawValue = newValue.rawValue }
    }

    static func makeItemKey(playlistID: String, sortIndex: Int) -> String {
        "\(playlistID)::\(sortIndex)"
    }
}
