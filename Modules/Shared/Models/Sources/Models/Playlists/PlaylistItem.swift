import Foundation
import SwiftData

public enum PlaylistItemImportStatus: String, Codable, CaseIterable, Sendable {
    case pending
    case matched
    case uncertain
    case failed
    case skipped
}

@Model
public final class PlaylistItem {
    @Attribute(.unique) public var itemKey: String

    public var playlistID: String
    public var sortIndex: Int

    public var sourceTrackID: String?
    public var sourceTrackFingerprint: String

    public var title: String
    public var artistName: String?
    public var albumName: String?
    public var durationSeconds: Double?
    public var artworkURLString: String?

    public var resolvedMediaID: String?
    public var resolutionConfidence: Double?

    public var importStatusRawValue: String
    public var importErrorCode: String?
    public var importErrorMessage: String?

    public var createdAt: Date
    public var updatedAt: Date

    public init(
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

    public var importStatus: PlaylistItemImportStatus {
        get { PlaylistItemImportStatus(rawValue: importStatusRawValue) ?? .pending }
        set { importStatusRawValue = newValue.rawValue }
    }

    public static func makeItemKey(playlistID: String, sortIndex: Int) -> String {
        "\(playlistID)::\(sortIndex)"
    }
}
