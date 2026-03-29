import Foundation
import SwiftData

enum PlaylistImportTrackState: String, Codable, CaseIterable, Sendable {
    case pending
    case resolved
    case uncertain
    case failed
    case skipped
}

@Model
final class PlaylistImportTrackEntry {
    @Attribute(.unique) var trackEntryID: String

    var jobID: String
    var sourceTrackID: String?
    var sourceTrackFingerprint: String
    var sourceIndex: Int

    var title: String
    var artistName: String?
    var albumName: String?
    var durationSeconds: Double?

    var stateRawValue: String
    var selectedCandidateID: String?
    var resolvedMediaID: String?
    var confidenceScore: Double?
    var needsReview: Bool

    var errorCode: String?
    var errorMessage: String?

    var updatedAt: Date

    init(
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

    var state: PlaylistImportTrackState {
        get { PlaylistImportTrackState(rawValue: stateRawValue) ?? .pending }
        set { stateRawValue = newValue.rawValue }
    }

    static func makeTrackEntryID(jobID: String, sourceIndex: Int) -> String {
        "\(jobID)::\(sourceIndex)"
    }
}
