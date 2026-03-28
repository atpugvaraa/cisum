import Foundation
import SwiftData
import YouTubeSDK

@MainActor
final class MediaCacheStore {
    struct MaintenancePolicy {
        let playbackMaxAge: TimeInterval
        let artworkURLMaxAge: TimeInterval
        let motionArtworkMaxAge: TimeInterval
        let localArtworkMaxAge: TimeInterval
        let entryRetentionAge: TimeInterval
        let maxEntries: Int

        static let `default` = MaintenancePolicy(
            playbackMaxAge: 60 * 60 * 12,
            artworkURLMaxAge: 60 * 60 * 24 * 14,
            motionArtworkMaxAge: 60 * 60 * 24,
            localArtworkMaxAge: 60 * 60 * 24 * 21,
            entryRetentionAge: 60 * 60 * 24 * 30,
            maxEntries: 600
        )
    }

    private let context: ModelContext
    private let imageFileStore: ArtworkImageFileStore

    init(context: ModelContext, imageFileStore: ArtworkImageFileStore = .shared) {
        self.context = context
        self.imageFileStore = imageFileStore
    }

    func playbackCandidates(for mediaID: String, maxAge: TimeInterval) -> [URL]? {
        guard let entry = fetchEntry(for: mediaID),
              let updatedAt = entry.playbackUpdatedAt,
              Date().timeIntervalSince(updatedAt) <= maxAge else {
            return nil
        }

        entry.lastAccessedAt = .now
        saveContext()

        let preferred = url(from: entry.playbackPreferredURLString)
        let hls = url(from: entry.playbackHLSURLString)
        let muxed = url(from: entry.playbackMuxedURLString)
        let audio = compatibleAudioURL(
            from: entry.playbackAudioURLString,
            mimeType: entry.playbackAudioMimeType
        )

        let candidates = deduplicatedURLs([preferred, hls, muxed, audio])
        return candidates.isEmpty ? nil : candidates
    }

    func savePlaybackResolution(mediaID: String, preferredURL: URL, video: YouTubeVideo) {
        let entry = entryForWrite(mediaID: mediaID)
        entry.playbackPreferredURLString = preferredURL.absoluteString
        entry.playbackHLSURLString = video.hlsURL?.absoluteString
        entry.playbackMuxedURLString = video.bestMuxedStream?.url
        entry.playbackAudioURLString = video.bestAudioStream?.url
        entry.playbackAudioMimeType = video.bestAudioStream?.mimeType
        entry.playbackUpdatedAt = .now
        entry.lastAccessedAt = .now
        saveContext()
    }

    func invalidatePlayback(for mediaID: String) {
        guard let entry = fetchEntry(for: mediaID) else { return }
        entry.playbackPreferredURLString = nil
        entry.playbackHLSURLString = nil
        entry.playbackMuxedURLString = nil
        entry.playbackAudioURLString = nil
        entry.playbackAudioMimeType = nil
        entry.playbackUpdatedAt = nil
        entry.lastAccessedAt = .now
        saveContext()
    }

    func cachedHighQualityArtworkURL(for mediaID: String, maxAge: TimeInterval) -> URL? {
        guard let entry = fetchEntry(for: mediaID),
              let updatedAt = entry.artworkUpdatedAt,
              Date().timeIntervalSince(updatedAt) <= maxAge,
              let url = url(from: entry.artworkURL1500String) else {
            return nil
        }

        entry.lastAccessedAt = .now
        saveContext()
        return url
    }

    func saveHighQualityArtworkURL(_ url: URL, for mediaID: String) {
        let entry = entryForWrite(mediaID: mediaID)
        entry.artworkURL1500String = url.absoluteString
        entry.artworkUpdatedAt = .now
        entry.lastAccessedAt = .now
        saveContext()
    }

    func cachedMotionArtworkSourceURL(for mediaID: String, maxAge: TimeInterval) -> URL? {
        guard let entry = fetchEntry(for: mediaID),
              let updatedAt = entry.motionArtworkUpdatedAt,
              Date().timeIntervalSince(updatedAt) <= maxAge,
              let url = url(from: entry.motionArtworkHLSURLString) else {
            return nil
        }

        entry.lastAccessedAt = .now
        saveContext()
        return url
    }

    func saveMotionArtworkSourceURL(_ url: URL, for mediaID: String) {
        let entry = entryForWrite(mediaID: mediaID)
        entry.motionArtworkHLSURLString = url.absoluteString
        entry.motionArtworkUpdatedAt = .now
        entry.lastAccessedAt = .now
        saveContext()
    }

    func cachedLocalArtworkData(for mediaID: String) async -> (url: URL, data: Data)? {
        guard let entry = fetchEntry(for: mediaID),
              let filename = entry.localArtworkFilename,
              let fileURL = await imageFileStore.existingFileURL(named: filename),
              let data = await imageFileStore.readData(named: filename) else {
            return nil
        }

        entry.lastAccessedAt = .now
        saveContext()
        return (fileURL, data)
    }

    func saveArtworkData(_ data: Data, mediaID: String, sourceURL: URL) async -> URL? {
        guard let writeResult = await imageFileStore.write(data: data, mediaID: mediaID) else {
            return nil
        }

        let entry = entryForWrite(mediaID: mediaID)
        entry.artworkURL1500String = sourceURL.absoluteString
        entry.artworkUpdatedAt = .now
        entry.localArtworkFilename = writeResult.filename
        entry.localArtworkUpdatedAt = .now
        entry.lastAccessedAt = .now
        saveContext()
        return writeResult.url
    }

    func performMaintenance(policy: MaintenancePolicy = .default) async {
        let now = Date()
        let entries = allEntries()

        for entry in entries {
            await pruneExpiredPayloads(in: entry, now: now, policy: policy)

            let hasPayload = hasAnyCachedPayload(in: entry)
            let idleTime = now.timeIntervalSince(entry.lastAccessedAt)
            if !hasPayload && idleTime > policy.entryRetentionAge {
                context.delete(entry)
            }
        }

        enforceEntryLimit(policy.maxEntries)
        saveContext()

        let keepFilenames = Set(allEntries().compactMap(\.localArtworkFilename))
        await imageFileStore.pruneOrphanedFiles(
            keeping: keepFilenames,
            maxFileAge: policy.localArtworkMaxAge
        )
    }

    private func entryForWrite(mediaID: String) -> MediaCacheEntry {
        if let existing = fetchEntry(for: mediaID) {
            return existing
        }

        let created = MediaCacheEntry(mediaID: mediaID)
        context.insert(created)
        return created
    }

    private func fetchEntry(for mediaID: String) -> MediaCacheEntry? {
        var descriptor = FetchDescriptor<MediaCacheEntry>(
            predicate: #Predicate { $0.mediaID == mediaID }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func url(from string: String?) -> URL? {
        guard let string else { return nil }
        return URL(string: string)
    }

    private func compatibleAudioURL(from urlString: String?, mimeType: String?) -> URL? {
        guard let urlString,
              let url = URL(string: urlString) else {
            return nil
        }

        guard let mimeType else {
            return url
        }

        let normalized = mimeType.lowercased()
        if normalized.contains("webm") {
            return nil
        }

        if normalized.contains("mp4")
            || normalized.contains("mpeg")
            || normalized.contains("aac")
            || normalized.contains("mp3") {
            return url
        }

        return nil
    }

    private func deduplicatedURLs(_ urls: [URL?]) -> [URL] {
        var seen: Set<String> = []
        var result: [URL] = []

        for url in urls.compactMap({ $0 }) {
            let key = url.absoluteString
            if seen.contains(key) { continue }
            seen.insert(key)
            result.append(url)
        }

        return result
    }

    private func allEntries() -> [MediaCacheEntry] {
        let descriptor = FetchDescriptor<MediaCacheEntry>()
        return (try? context.fetch(descriptor)) ?? []
    }

    private func pruneExpiredPayloads(in entry: MediaCacheEntry, now: Date, policy: MaintenancePolicy) async {
        if let updatedAt = entry.playbackUpdatedAt,
           now.timeIntervalSince(updatedAt) > policy.playbackMaxAge {
            entry.playbackPreferredURLString = nil
            entry.playbackHLSURLString = nil
            entry.playbackMuxedURLString = nil
            entry.playbackAudioURLString = nil
            entry.playbackAudioMimeType = nil
            entry.playbackUpdatedAt = nil
        }

        if let updatedAt = entry.artworkUpdatedAt,
           now.timeIntervalSince(updatedAt) > policy.artworkURLMaxAge {
            entry.artworkURL1500String = nil
            entry.artworkUpdatedAt = nil
        }

        if let updatedAt = entry.motionArtworkUpdatedAt,
           now.timeIntervalSince(updatedAt) > policy.motionArtworkMaxAge {
            entry.motionArtworkHLSURLString = nil
            entry.motionArtworkUpdatedAt = nil
        }

        var shouldClearLocalArtwork = false
        if let localUpdatedAt = entry.localArtworkUpdatedAt,
           now.timeIntervalSince(localUpdatedAt) > policy.localArtworkMaxAge {
            shouldClearLocalArtwork = true
        }

        if !shouldClearLocalArtwork,
           let filename = entry.localArtworkFilename {
            let exists = await imageFileStore.fileExists(named: filename)
            if !exists {
                shouldClearLocalArtwork = true
            }
        }

        if shouldClearLocalArtwork,
           let filename = entry.localArtworkFilename {
            await imageFileStore.removeFile(named: filename)
            entry.localArtworkFilename = nil
            entry.localArtworkUpdatedAt = nil
        }
    }

    private func enforceEntryLimit(_ maxEntries: Int) {
        guard maxEntries > 0 else { return }

        let sorted = allEntries().sorted { lhs, rhs in
            lhs.lastAccessedAt > rhs.lastAccessedAt
        }

        guard sorted.count > maxEntries else { return }

        for entry in sorted.dropFirst(maxEntries) {
            context.delete(entry)
        }
    }

    private func hasAnyCachedPayload(in entry: MediaCacheEntry) -> Bool {
        entry.playbackPreferredURLString != nil
            || entry.playbackHLSURLString != nil
            || entry.playbackMuxedURLString != nil
            || entry.playbackAudioURLString != nil
            || entry.artworkURL1500String != nil
            || entry.localArtworkFilename != nil
            || entry.motionArtworkHLSURLString != nil
    }

    private func saveContext() {
        try? context.save()
    }
}

actor ArtworkImageFileStore {
    struct WriteResult {
        let filename: String
        let url: URL
    }

    typealias AppGroupContainerURLProvider = @Sendable (String) -> URL?

    static let shared = ArtworkImageFileStore()

    private let fileManager: FileManager
    private let appGroupIdentifier: String
    private let appGroupContainerURLProvider: AppGroupContainerURLProvider

    init(
        fileManager: FileManager = .default,
        appGroupIdentifier: String = "group.aaravgupta.cisum",
        appGroupContainerURLProvider: @escaping AppGroupContainerURLProvider = { identifier in
            FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
        }
    ) {
        self.fileManager = fileManager
        self.appGroupIdentifier = appGroupIdentifier
        self.appGroupContainerURLProvider = appGroupContainerURLProvider
    }

    func write(data: Data, mediaID: String) -> WriteResult? {
        guard let directory = cacheDirectoryURL() else { return nil }

        do {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: nil
            )

            let filename = sanitizedFilename(for: mediaID)
            let fileURL = directory.appending(path: filename)
            try data.write(to: fileURL, options: .atomic)
            return WriteResult(filename: filename, url: fileURL)
        } catch {
            return nil
        }
    }

    func existingFileURL(named filename: String) -> URL? {
        guard let directory = cacheDirectoryURL() else { return nil }
        let fileURL = directory.appending(path: filename)

        guard fileManager.fileExists(atPath: fileURL.path(percentEncoded: false)) else {
            return nil
        }

        return fileURL
    }

    func readData(named filename: String) -> Data? {
        guard let fileURL = existingFileURL(named: filename) else {
            return nil
        }

        return try? Data(contentsOf: fileURL)
    }

    func fileExists(named filename: String) -> Bool {
        guard let fileURL = existingFileURL(named: filename) else {
            return false
        }

        return fileManager.fileExists(atPath: fileURL.path(percentEncoded: false))
    }

    func removeFile(named filename: String) {
        guard let fileURL = existingFileURL(named: filename) else {
            return
        }

        try? fileManager.removeItem(at: fileURL)
    }

    func pruneOrphanedFiles(keeping keepFilenames: Set<String>, maxFileAge: TimeInterval) {
        guard let directory = cacheDirectoryURL() else { return }
        guard let items = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        let now = Date()
        for item in items {
            let filename = item.lastPathComponent

            let isStale: Bool
            if let values = try? item.resourceValues(forKeys: [.contentModificationDateKey]),
               let modifiedAt = values.contentModificationDate {
                isStale = now.timeIntervalSince(modifiedAt) > maxFileAge
            } else {
                isStale = false
            }

            if !keepFilenames.contains(filename) || isStale {
                try? fileManager.removeItem(at: item)
            }
        }
    }

    private func cacheDirectoryURL() -> URL? {
        guard let containerURL = appGroupContainerURLProvider(appGroupIdentifier) else {
            return nil
        }

        return containerURL
            .appending(path: "Library", directoryHint: .isDirectory)
            .appending(path: "Caches", directoryHint: .isDirectory)
            .appending(path: "ArtworkImages", directoryHint: .isDirectory)
    }

    private func sanitizedFilename(for mediaID: String) -> String {
        let allowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
        let normalized = mediaID.map { allowed.contains($0) ? $0 : "_" }
        return String(normalized) + ".img"
    }
}
