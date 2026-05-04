import Foundation
import SwiftData

public enum PlaylistImportTrackState: String, Codable, CaseIterable, Sendable {
    case pending
    case resolved
    case uncertain
    case failed
    case skipped
}

@Model
public final class PlaylistImportTrackEntry {
    @Attribute(.unique) public var trackEntryID: String

    public var jobID: String
    public var sourceTrackID: String?
    public var sourceTrackFingerprint: String
    public var sourceIndex: Int

    public var title: String
    public var artistName: String?
    public var albumName: String?
    public var durationSeconds: Double?

    public var stateRawValue: String
    public var selectedCandidateID: String?
    public var resolvedMediaID: String?
    public var confidenceScore: Double?
    public var needsReview: Bool

    public var errorCode: String?
    public var errorMessage: String?

    public var updatedAt: Date

    public init(
        jobID: String,
        sourceTrackID: String? = nil,
        sourceTrackFingerprint: String,
        sourceIndex: Int,
        title: String,
        artistName: String? = nil,
        albumName: String? = nil,
        durationSeconds: Double? = nil,
        state: PlaylistImportTrackState = .pending,
        selectedCandidateID: String? = nil,
        resolvedMediaID: String? = nil,
        confidenceScore: Double? = nil,
        needsReview: Bool = false,
        errorCode: String? = nil,
        errorMessage: String? = nil,
        updatedAt: Date = .now
    ) {
        self.trackEntryID = Self.makeTrackEntryID(jobID: jobID, sourceIndex: sourceIndex)
        self.jobID = jobID
        self.sourceTrackID = sourceTrackID
        self.sourceTrackFingerprint = sourceTrackFingerprint
        self.sourceIndex = sourceIndex
        self.title = title
        self.artistName = artistName
        self.albumName = albumName
        self.durationSeconds = durationSeconds
        self.stateRawValue = state.rawValue
        self.selectedCandidateID = selectedCandidateID
        self.resolvedMediaID = resolvedMediaID
        self.confidenceScore = confidenceScore
        self.needsReview = needsReview
        self.errorCode = errorCode
        self.errorMessage = errorMessage
        self.updatedAt = updatedAt
    }

    public var state: PlaylistImportTrackState {
        get { PlaylistImportTrackState(rawValue: stateRawValue) ?? .pending }
        set { stateRawValue = newValue.rawValue }
    }

    public static func makeTrackEntryID(jobID: String, sourceIndex: Int) -> String {
        "\(jobID)::\(sourceIndex)"
    }
}
