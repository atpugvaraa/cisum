import Foundation
import SwiftData
import Models

@MainActor
public final class PlaylistImportJobStore {
    public struct JobSnapshot: Sendable {
        public let jobID: String
        public let idempotencyKey: String
        public let sourceProvider: PlaylistSource
        public let sourcePlaylistID: String
        public let sourcePlaylistName: String?
        public let sourceURLString: String?
        public let state: PlaylistImportJobState
        public let requiresReview: Bool
        public let totalTrackCount: Int
        public let processedTrackCount: Int
        public let matchedTrackCount: Int
        public let uncertainTrackCount: Int
        public let failedTrackCount: Int
        public let nextTrackOffset: Int
        public let resumeToken: String?
        public let destinationPlaylistID: String?
        public let enqueuedAt: Date
        public let startedAt: Date?
        public let finishedAt: Date?
        public let lastCheckpointAt: Date?
        public let lastErrorCode: String?
        public let lastErrorMessage: String?

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
            self.sourceProvider = sourceProvider
            self.sourcePlaylistID = sourcePlaylistID
            self.sourcePlaylistName = sourcePlaylistName
            self.sourceURLString = sourceURLString
            self.state = state
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
    }

    public struct TrackSnapshot: Sendable {
        public let trackEntryID: String
        public let jobID: String
        public let sourceTrackID: String?
        public let sourceTrackFingerprint: String
        public let sourceIndex: Int
        public let title: String
        public let artistName: String?
        public let albumName: String?
        public let durationSeconds: Double?
        public let state: PlaylistImportTrackState
        public let selectedCandidateID: String?
        public let resolvedMediaID: String?
        public let confidenceScore: Double?
        public let needsReview: Bool
        public let errorCode: String?
        public let errorMessage: String?
        public let updatedAt: Date

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
            self.trackEntryID = PlaylistImportTrackEntry.makeTrackEntryID(jobID: jobID, sourceIndex: sourceIndex)
            self.jobID = jobID
            self.sourceTrackID = sourceTrackID
            self.sourceTrackFingerprint = sourceTrackFingerprint
            self.sourceIndex = sourceIndex
            self.title = title
            self.artistName = artistName
            self.albumName = albumName
            self.durationSeconds = durationSeconds
            self.state = state
            self.selectedCandidateID = selectedCandidateID
            self.resolvedMediaID = resolvedMediaID
            self.confidenceScore = confidenceScore
            self.needsReview = needsReview
            self.errorCode = errorCode
            self.errorMessage = errorMessage
            self.updatedAt = updatedAt
        }
    }

    public struct CandidateSnapshot: Sendable {
        public let candidateID: String
        public let trackEntryID: String
        public let mediaID: String
        public let title: String
        public let artistName: String?
        public let albumName: String?
        public let artworkURLString: String?
        public let durationSeconds: Double?
        public let confidenceScore: Double
        public let rank: Int

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

    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    public func createOrReuseJob(_ snapshot: JobSnapshot) -> PlaylistImportJobEntry {
        if let existing = jobForIdempotencyKey(snapshot.idempotencyKey) {
            apply(snapshot, onto: existing)
            saveContext()
            return existing
        }

        if let existing = job(jobID: snapshot.jobID) {
            apply(snapshot, onto: existing)
            saveContext()
            return existing
        }

        let created = PlaylistImportJobEntry(
            jobID: snapshot.jobID,
            idempotencyKey: snapshot.idempotencyKey,
            sourceProvider: snapshot.sourceProvider,
            sourcePlaylistID: snapshot.sourcePlaylistID,
            sourcePlaylistName: snapshot.sourcePlaylistName,
            sourceURLString: snapshot.sourceURLString,
            state: snapshot.state,
            requiresReview: snapshot.requiresReview,
            totalTrackCount: snapshot.totalTrackCount,
            processedTrackCount: snapshot.processedTrackCount,
            matchedTrackCount: snapshot.matchedTrackCount,
            uncertainTrackCount: snapshot.uncertainTrackCount,
            failedTrackCount: snapshot.failedTrackCount,
            nextTrackOffset: snapshot.nextTrackOffset,
            resumeToken: snapshot.resumeToken,
            destinationPlaylistID: snapshot.destinationPlaylistID,
            enqueuedAt: snapshot.enqueuedAt,
            startedAt: snapshot.startedAt,
            finishedAt: snapshot.finishedAt,
            lastCheckpointAt: snapshot.lastCheckpointAt,
            lastErrorCode: snapshot.lastErrorCode,
            lastErrorMessage: snapshot.lastErrorMessage
        )
        context.insert(created)
        saveContext()
        return created
    }

    public func updateJob(_ snapshot: JobSnapshot) {
        guard let existing = job(jobID: snapshot.jobID) else {
            _ = createOrReuseJob(snapshot)
            return
        }

        apply(snapshot, onto: existing)
        saveContext()
    }

    public func job(jobID: String) -> PlaylistImportJobEntry? {
        var descriptor = FetchDescriptor<PlaylistImportJobEntry>(
            predicate: #Predicate { $0.jobID == jobID }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    public func pendingJobs(limit: Int = 20) -> [PlaylistImportJobEntry] {
        let queued = PlaylistImportJobState.queued.rawValue
        let running = PlaylistImportJobState.running.rawValue

        var descriptor = FetchDescriptor<PlaylistImportJobEntry>(
            predicate: #Predicate {
                $0.stateRawValue == queued || $0.stateRawValue == running
            },
            sortBy: [SortDescriptor(\PlaylistImportJobEntry.enqueuedAt, order: .forward)]
        )

        if limit > 0 {
            descriptor.fetchLimit = limit
        }

        return (try? context.fetch(descriptor)) ?? []
    }

    public func tracks(for jobID: String) -> [PlaylistImportTrackEntry] {
        let descriptor = FetchDescriptor<PlaylistImportTrackEntry>(
            predicate: #Predicate { $0.jobID == jobID },
            sortBy: [SortDescriptor(\PlaylistImportTrackEntry.sourceIndex, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    public func candidates(for trackEntryID: String) -> [PlaylistImportCandidateEntry] {
        let descriptor = FetchDescriptor<PlaylistImportCandidateEntry>(
            predicate: #Predicate { $0.trackEntryID == trackEntryID },
            sortBy: [SortDescriptor(\PlaylistImportCandidateEntry.rank, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    public func replaceTracks(for jobID: String, with snapshots: [TrackSnapshot]) {
        let existingTracks = tracks(for: jobID)
        for existing in existingTracks {
            deleteCandidates(for: existing.trackEntryID)
            context.delete(existing)
        }

        for snapshot in snapshots.sorted(by: { $0.sourceIndex < $1.sourceIndex }) {
            let created = PlaylistImportTrackEntry(
                jobID: snapshot.jobID,
                sourceTrackID: snapshot.sourceTrackID,
                sourceTrackFingerprint: snapshot.sourceTrackFingerprint,
                sourceIndex: snapshot.sourceIndex,
                title: snapshot.title,
                artistName: snapshot.artistName,
                albumName: snapshot.albumName,
                durationSeconds: snapshot.durationSeconds,
                state: snapshot.state,
                selectedCandidateID: snapshot.selectedCandidateID,
                resolvedMediaID: snapshot.resolvedMediaID,
                confidenceScore: snapshot.confidenceScore,
                needsReview: snapshot.needsReview,
                errorCode: snapshot.errorCode,
                errorMessage: snapshot.errorMessage,
                updatedAt: snapshot.updatedAt
            )
            context.insert(created)
        }

        saveContext()
    }

    public func replaceCandidates(for trackEntryID: String, with snapshots: [CandidateSnapshot]) {
        deleteCandidates(for: trackEntryID)

        for snapshot in snapshots.sorted(by: { $0.rank < $1.rank }) {
            let created = PlaylistImportCandidateEntry(
                candidateID: snapshot.candidateID,
                trackEntryID: snapshot.trackEntryID,
                mediaID: snapshot.mediaID,
                title: snapshot.title,
                artistName: snapshot.artistName,
                albumName: snapshot.albumName,
                artworkURLString: snapshot.artworkURLString,
                durationSeconds: snapshot.durationSeconds,
                confidenceScore: snapshot.confidenceScore,
                rank: snapshot.rank
            )
            context.insert(created)
        }

        saveContext()
    }

    public func checkpoint(
        jobID: String,
        nextTrackOffset: Int,
        resumeToken: String?,
        processedTrackCount: Int,
        matchedTrackCount: Int,
        uncertainTrackCount: Int,
        failedTrackCount: Int,
        requiresReview: Bool
    ) {
        guard let job = job(jobID: jobID) else {
            return
        }

        job.nextTrackOffset = max(0, nextTrackOffset)
        job.resumeToken = resumeToken
        job.processedTrackCount = max(0, processedTrackCount)
        job.matchedTrackCount = max(0, matchedTrackCount)
        job.uncertainTrackCount = max(0, uncertainTrackCount)
        job.failedTrackCount = max(0, failedTrackCount)
        job.requiresReview = requiresReview
        job.lastCheckpointAt = .now
        job.state = .running
        saveContext()
    }

    public func finish(
        jobID: String,
        state: PlaylistImportJobState,
        destinationPlaylistID: String?,
        lastErrorCode: String? = nil,
        lastErrorMessage: String? = nil
    ) {
        guard let job = job(jobID: jobID) else {
            return
        }

        job.state = state
        job.destinationPlaylistID = destinationPlaylistID
        job.finishedAt = .now
        job.lastCheckpointAt = .now
        job.lastErrorCode = lastErrorCode
        job.lastErrorMessage = lastErrorMessage
        saveContext()
    }

    private func jobForIdempotencyKey(_ idempotencyKey: String) -> PlaylistImportJobEntry? {
        var descriptor = FetchDescriptor<PlaylistImportJobEntry>(
            predicate: #Predicate { $0.idempotencyKey == idempotencyKey }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func deleteCandidates(for trackEntryID: String) {
        for candidate in candidates(for: trackEntryID) {
            context.delete(candidate)
        }
    }

    private func apply(_ snapshot: JobSnapshot, onto entry: PlaylistImportJobEntry) {
        entry.idempotencyKey = snapshot.idempotencyKey
        entry.sourceProvider = snapshot.sourceProvider
        entry.sourcePlaylistID = snapshot.sourcePlaylistID
        entry.sourcePlaylistName = snapshot.sourcePlaylistName
        entry.sourceURLString = snapshot.sourceURLString
        entry.state = snapshot.state
        entry.requiresReview = snapshot.requiresReview
        entry.totalTrackCount = snapshot.totalTrackCount
        entry.processedTrackCount = snapshot.processedTrackCount
        entry.matchedTrackCount = snapshot.matchedTrackCount
        entry.uncertainTrackCount = snapshot.uncertainTrackCount
        entry.failedTrackCount = snapshot.failedTrackCount
        entry.nextTrackOffset = snapshot.nextTrackOffset
        entry.resumeToken = snapshot.resumeToken
        entry.destinationPlaylistID = snapshot.destinationPlaylistID
        entry.enqueuedAt = snapshot.enqueuedAt
        entry.startedAt = snapshot.startedAt
        entry.finishedAt = snapshot.finishedAt
        entry.lastCheckpointAt = snapshot.lastCheckpointAt
        entry.lastErrorCode = snapshot.lastErrorCode
        entry.lastErrorMessage = snapshot.lastErrorMessage
    }

    private func saveContext() {
        try? context.save()
    }
}