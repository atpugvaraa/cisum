import Foundation
import Services

#if canImport(LyricsKit)
import LyricsKit
#endif

@MainActor
extension PlayerViewModel {

    public var currentSyncedLyricIndex: Int? {
        guard !self.syncedLyricsLines.isEmpty else { return nil }

        let playbackTime = max(self.currentTime, 0)
        if let firstTimestamp = self.syncedLyricsLines.first?.timestamp,
           playbackTime < firstTimestamp {
            return 0
        }

        return self.syncedLyricsLines.lastIndex { line in
            line.timestamp <= playbackTime
        }
    }

    var currentSyncedLyricText: String? {
        guard let index = currentSyncedLyricIndex,
              self.syncedLyricsLines.indices.contains(index) else {
            return nil
        }

        return self.syncedLyricsLines[index].text
    }

    var upcomingSyncedLyricText: String? {
        guard let index = currentSyncedLyricIndex else { return nil }
        let nextIndex = index + 1
        guard self.syncedLyricsLines.indices.contains(nextIndex) else { return nil }
        return self.syncedLyricsLines[nextIndex].text
    }

    func startLyricsResolution(
        mediaID: String,
        title: String,
        artist: String,
        albumName: String?,
        durationHint: Int?
    ) {
        self.lyricsLoadTask?.cancel()
        self.lyricsController.reset()

        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedAlbum = Self.nonEmptyTrimmed(albumName)

        guard !normalizedTitle.isEmpty else {
            self.lyricsController.state = .idle
            return
        }

#if canImport(LyricsKit)
        self.lyricsController.state = .loading
        self.lyricsLoadTask = Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                let resolvedLyrics = try await Self.resolveLyrics(
                    title: normalizedTitle,
                    artist: normalizedArtist,
                    albumName: normalizedAlbum,
                    durationHint: durationHint
                )

                guard !Task.isCancelled, self.currentVideoId == mediaID else { return }

                self.lyricsController.loadLyrics(
                    synced: resolvedLyrics.syncedLines,
                    plain: resolvedLyrics.plainText,
                    attribution: resolvedLyrics.attribution
                )
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, self.currentVideoId == mediaID else { return }
                self.lyricsController.state = .unavailable(error.localizedDescription)
            }
        }
#else
    self.lyricsController.state = .unavailable("LyricsKit is not linked to this target.")
#endif
    }

#if canImport(LyricsKit)
    private struct LyricsResolution {
        let syncedLines: [TimedLyricLine]
        let plainText: String?
        let attribution: String?
    }

    private static func resolveLyrics(
        title: String,
        artist: String,
        albumName: String?,
        durationHint: Int?
    ) async throws -> LyricsResolution {
        let kit = LyricsKit.shared
        let artistName = nonEmptyTrimmed(artist)
        let album = nonEmptyTrimmed(albumName)

        if let durationHint,
           durationHint > 0,
           let artistName {
            let signatureAlbum = album ?? "Single"
            if let best = try await kit.bestLyrics(
                trackName: title,
                artistName: artistName,
                albumName: signatureAlbum,
                durationInSeconds: durationHint
            ) {
                let mapped = mapLyricsRecord(best)
                if !mapped.syncedLines.isEmpty || mapped.plainText != nil {
                    return mapped
                }
            }
        }

        let syncedCandidates = try await kit.searchSynced(
            trackName: title,
            artistName: artistName,
            albumName: album
        )

        if let syncedMatch = syncedCandidates.first {
            let mapped = mapLyricsRecord(syncedMatch)
            if !mapped.syncedLines.isEmpty || mapped.plainText != nil {
                return mapped
            }
        }

        let fallbackCandidates = try await kit.search(
            trackName: title,
            artistName: artistName,
            albumName: album
        )

        if let firstFallback = fallbackCandidates.first {
            return mapLyricsRecord(firstFallback)
        }

        return LyricsResolution(syncedLines: [], plainText: nil, attribution: nil)
    }

    private static func mapLyricsRecord(_ record: LyricsRecord) -> LyricsResolution {
        let syncedLines: [TimedLyricLine] = (record.parsedSyncedLyrics?.lines ?? [])
            .compactMap { line in
                let text = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return nil }
                return TimedLyricLine(timestamp: line.timestamp, text: text)
            }

        var plainLyrics = nonEmptyTrimmed(record.plainLyrics)
        if plainLyrics == nil, record.instrumental {
            plainLyrics = "Instrumental"
        }

        let attributionParts = [
            nonEmptyTrimmed(record.artistName),
            nonEmptyTrimmed(record.trackName)
        ]
        .compactMap { $0 }
        let attribution = attributionParts.isEmpty ? nil : attributionParts.joined(separator: " • ")

        return LyricsResolution(
            syncedLines: syncedLines,
            plainText: plainLyrics,
            attribution: attribution
        )
    }
#endif

    private static func nonEmptyTrimmed(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }

        return value
    }

    static func lyricsDurationHint(from duration: TimeInterval?) -> Int? {
        guard let duration,
              duration.isFinite,
              duration > 0 else {
            return nil
        }

        return Int(duration.rounded())
    }

    static func lyricsDurationHint(from rawDuration: String) -> Int? {
        let trimmed = rawDuration.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let directSeconds = Int(trimmed), directSeconds > 0 {
            return directSeconds
        }

        let parts = trimmed.split(separator: ":").compactMap { Int($0) }
        if parts.count == 2 {
            return (parts[0] * 60) + parts[1]
        }
        if parts.count == 3 {
            return (parts[0] * 3600) + (parts[1] * 60) + parts[2]
        }

        return nil
    }
}
