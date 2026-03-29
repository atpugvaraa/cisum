import Foundation
import SwiftData

@MainActor
final class PlaylistImportJobStore {
    struct JobSnapshot: Sendable {
        let jobID: String
        let idempotencyKey: String
        let sourceProvider: PlaylistSourceProvider
        let sourcePlaylistID: String
        let sourcePlaylistName: String?
        let sourceURLString: String?
        let state: PlaylistImportJobState
        let requiresReview: Bool
        let totalTrackCount: Int
        let processedTrackCount: Int
        let matchedTrackCount: Int
        let uncertainTrackCount: Int
        let failedTrackCount: Int
        let nextTrackOffset: Int
        let resumeToken: String?
        let destinationPlaylistID: String?
        let enqueuedAt: Date
        let startedAt: Date?
        let finishedAt: Date?
        let lastCheckpointAt: Date?
        let lastErrorCode: String?
        let lastErrorMessage: String?

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

    struct TrackSnapshot: Sendable {
        let trackEntryID: String
        let jobID: String
        let sourceTrackID: String?
        let sourceTrackFingerprint: String
        let sourceIndex: Int
        let title: String
        let artistName: String?
        let albumName: String?
        let durationSeconds: Double?
        let state: PlaylistImportTrackState
        let selectedCandidateID: String?
        let resolvedMediaID: String?
        let confidenceScore: Double?
        let needsReview: Bool
        let errorCode: String?
        let errorMessage: String?
        let updatedAt: Date

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

    struct CandidateSnapshot: Sendable {
        let candidateID: String
        let trackEntryID: String
        let mediaID: String
        let title: String
        let artistName: String?
        let albumName: String?
        let artworkURLString: String?
        let durationSeconds: Double?
        let confidenceScore: Double
        let rank: Int

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

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    func createOrReuseJob(_ snapshot: JobSnapshot) -> PlaylistImportJobEntry {
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

    func updateJob(_ snapshot: JobSnapshot) {
        guard let existing = job(jobID: snapshot.jobID) else {
            _ = createOrReuseJob(snapshot)
            return
        }

        apply(snapshot, onto: existing)
        saveContext()
    }

    func job(jobID: String) -> PlaylistImportJobEntry? {
        var descriptor = FetchDescriptor<PlaylistImportJobEntry>(
            predicate: #Predicate { $0.jobID == jobID }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    func pendingJobs(limit: Int = 20) -> [PlaylistImportJobEntry] {
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

    func tracks(for jobID: String) -> [PlaylistImportTrackEntry] {
        let descriptor = FetchDescriptor<PlaylistImportTrackEntry>(
            predicate: #Predicate { $0.jobID == jobID },
            sortBy: [SortDescriptor(\PlaylistImportTrackEntry.sourceIndex, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func candidates(for trackEntryID: String) -> [PlaylistImportCandidateEntry] {
        let descriptor = FetchDescriptor<PlaylistImportCandidateEntry>(
            predicate: #Predicate { $0.trackEntryID == trackEntryID },
            sortBy: [SortDescriptor(\PlaylistImportCandidateEntry.rank, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func replaceTracks(for jobID: String, with snapshots: [TrackSnapshot]) {
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

    func replaceCandidates(for trackEntryID: String, with snapshots: [CandidateSnapshot]) {
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

    func checkpoint(
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

    func finish(
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