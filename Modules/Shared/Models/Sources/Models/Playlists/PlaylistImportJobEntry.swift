import Foundation
import SwiftData

public enum PlaylistImportJobState: String, Codable, CaseIterable, Sendable {
    case queued
    case running
    case completed
    case partialFailure = "partial_failure"
    case cancelled
    case failed
}

@Model
public final class PlaylistImportJobEntry {
    @Attribute(.unique) public var jobID: String
    @Attribute(.unique) public var idempotencyKey: String

    public var sourceProviderRawValue: String
    public var sourcePlaylistID: String
    public var sourcePlaylistName: String?
    public var sourceURLString: String?

    public var stateRawValue: String
    public var requiresReview: Bool

    public var totalTrackCount: Int
    public var processedTrackCount: Int
    public var matchedTrackCount: Int
    public var uncertainTrackCount: Int
    public var failedTrackCount: Int

    public var nextTrackOffset: Int
    public var resumeToken: String?

    public var destinationPlaylistID: String?

    public var enqueuedAt: Date
    public var startedAt: Date?
    public var finishedAt: Date?
    public var lastCheckpointAt: Date?

    public var lastErrorCode: String?
    public var lastErrorMessage: String?

    public init(
        jobID: String = UUID().uuidString,
        idempotencyKey: String,
        sourceProvider: PlaylistSource,
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

    public var sourceProvider: PlaylistSource {
        get { PlaylistSource(rawValue: sourceProviderRawValue) ?? .unknown }
        set { sourceProviderRawValue = newValue.rawValue }
    }

    public var state: PlaylistImportJobState {
        get { PlaylistImportJobState(rawValue: stateRawValue) ?? .queued }
        set { stateRawValue = newValue.rawValue }
    }
}

