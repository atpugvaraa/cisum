import Foundation
import SwiftData

enum PlaylistImportJobState: String, Codable, CaseIterable, Sendable {
    case queued
    case running
    case completed
    case partialFailure = "partial_failure"
    case cancelled
    case failed
}

@Model
final class PlaylistImportJobEntry {
    @Attribute(.unique) var jobID: String
    @Attribute(.unique) var idempotencyKey: String

    var sourceProviderRawValue: String
    var sourcePlaylistID: String
    var sourcePlaylistName: String?
    var sourceURLString: String?

    var stateRawValue: String
    var requiresReview: Bool

    var totalTrackCount: Int
    var processedTrackCount: Int
    var matchedTrackCount: Int
    var uncertainTrackCount: Int
    var failedTrackCount: Int

    var nextTrackOffset: Int
    var resumeToken: String?

    var destinationPlaylistID: String?

    var enqueuedAt: Date
    var startedAt: Date?
    var finishedAt: Date?
    var lastCheckpointAt: Date?

    var lastErrorCode: String?
    var lastErrorMessage: String?

    init(
        jobID: String = UUID().uuidString,
        idempotencyKey: String,
        sourceProvider: PlaylistSourceProvider,
        sourcePlaylistID: String,
        sourcePlaylistName: String? = nil,
        sourceURLString: String? = nil,
        state: PlaylistImportJobState = .queued,
        requiresReview: Bool = false,
        totalTrackCount: Int = 0,
        processedTrackCount: Int = 0,
        matchedTrackCount: Int = 0,
        uncertainTrackCount: Int = 0,
        failedTrackCount: Int = 0,
        nextTrackOffset: Int = 0,
        resumeToken: String? = nil,
        destinationPlaylistID: String? = nil,
        enqueuedAt: Date = .now,
        startedAt: Date? = nil,
        finishedAt: Date? = nil,
        lastCheckpointAt: Date? = nil,
        lastErrorCode: String? = nil,
        lastErrorMessage: String? = nil
    ) {
        self.jobID = jobID
        self.idempotencyKey = idempotencyKey
        self.sourceProviderRawValue = sourceProvider.rawValue
        self.sourcePlaylistID = sourcePlaylistID
        self.sourcePlaylistName = sourcePlaylistName
        self.sourceURLString = sourceURLString
        self.stateRawValue = state.rawValue
        self.requiresReview = requiresReview
        self.totalTrackCount = totalTrackCount
        self.processedTrackCount = processedTrackCount
        self.matchedTrackCount = matchedTrackCount
        self.uncertainTrackCount = uncertainTrackCount
        self.failedTrackCount = failedTrackCount
        self.nextTrackOffset = nextTrackOffset
        self.resumeToken = resumeToken
        self.destinationPlaylistID = destinationPlaylistID
        self.enqueuedAt = enqueuedAt
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.lastCheckpointAt = lastCheckpointAt
        self.lastErrorCode = lastErrorCode
        self.lastErrorMessage = lastErrorMessage
    }

    var sourceProvider: PlaylistSourceProvider {
        get { PlaylistSourceProvider(rawValue: sourceProviderRawValue) ?? .unknown }
        set { sourceProviderRawValue = newValue.rawValue }
    }

    var state: PlaylistImportJobState {
        get { PlaylistImportJobState(rawValue: stateRawValue) ?? .queued }
        set { stateRawValue = newValue.rawValue }
    }
}
