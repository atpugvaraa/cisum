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
                let aggregator = LyricsAggregator(youtube: self.youtube)
                
                let isSpotify = self.currentStreamingServiceName == StreamingService.spotify.rawValue
                
                let resolvedLyrics = try await aggregator.fetchBestLyrics(
                    title: normalizedTitle,
                    artist: normalizedArtist,
                    albumName: normalizedAlbum,
                    durationHint: durationHint,
                    spotifyTrackId: isSpotify ? mediaID : nil,
                    youtubeVideoId: isSpotify ? nil : mediaID
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
