import Utilities
import Foundation
import YouTubeSDK
import Models
import Services

@MainActor
extension PlayerViewModel {
    func preloadNextQueueEntryIfNeeded() {
        guard let queuePosition else {
            preparedNextPlayback = nil
            nextPlaybackPreloadTask?.cancel()
            nextPlaybackPreloadTask = nil
            preloadingNextMediaID = nil
            return
        }

        let nextIndex = queuePosition + 1
        guard playbackQueue.indices.contains(nextIndex) else {
            preparedNextPlayback = nil
            nextPlaybackPreloadTask?.cancel()
            nextPlaybackPreloadTask = nil
            preloadingNextMediaID = nil
            return
        }

        let nextEntry = playbackQueue[nextIndex]
        if preparedNextPlayback?.mediaID == nextEntry.mediaID {
            return
        }

        if preloadingNextMediaID == nextEntry.mediaID,
           nextPlaybackPreloadTask != nil {
            return
        }

        preparedNextPlayback = nil
        nextPlaybackPreloadTask?.cancel()
        preloadingNextMediaID = nextEntry.mediaID
        nextPlaybackPreloadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                if self.preloadingNextMediaID == nextEntry.mediaID {
                    self.preloadingNextMediaID = nil
                }
            }

            let prepared = await self.prepareQueuePlayback(for: nextEntry)
            guard !Task.isCancelled,
                  let prepared,
                  let currentQueuePosition = self.queuePosition else {
                return
            }

            let expectedIndex = currentQueuePosition + 1
            guard self.playbackQueue.indices.contains(expectedIndex),
                  self.playbackQueue[expectedIndex].mediaID == prepared.mediaID else {
                return
            }

            self.preparedNextPlayback = prepared
        }
    }

    private func prepareQueuePlayback(for entry: PlaybackQueueEntry) async -> PreparedQueuePlayback? {
        do {
            switch entry {
            case .song(let song):
                return try await prepareMusicQueuePlayback(
                    QueueMusicPreloadInput(
                        mediaID: song.videoId,
                        title: song.title,
                        artist: song.artistsDisplay,
                        albumName: song.album,
                        artworkURL: song.thumbnailURL,
                        isExplicit: song.isExplicit,
                        durationHint: Self.lyricsDurationHint(from: song.duration),
                        youtubeDebugSource: "youtube-fallback"
                    )
                )

            case .cachedRadio(let track):
                return try await prepareMusicQueuePlayback(
                    QueueMusicPreloadInput(
                        mediaID: track.videoID,
                        title: track.title,
                        artist: track.artist,
                        albumName: track.albumName,
                        artworkURL: track.thumbnailURL,
                        isExplicit: track.isExplicit,
                        durationHint: nil,
                        youtubeDebugSource: "radio-youtube-fallback"
                    )
                )

            case .video(let video):
                let candidates = try await resolvePlaybackCandidates(forID: video.id)
                guard let candidate = candidates.first else { return nil }
                let labels = playbackLabels(for: candidate)

                let prepared = PreparedQueuePlayback(
                    mediaID: video.id,
                    item: makePlayerItem(for: candidate.url, service: .youtube),
                    playbackCandidates: candidates,
                    preparedAt: .now,
                    title: normalizedMusicDisplayTitle(video.title, artist: video.author),
                    artist: normalizedMusicDisplayArtist(video.author, title: video.title),
                    artworkURL: normalizedArtworkURL(from: video.thumbnailURL),
                    streamingService: .youtube,
                    qualityLabel: labels.quality,
                    codecLabel: labels.codec,
                    albumName: nil,
                    isExplicit: false,
                    durationHint: Self.lyricsDurationHint(from: video.lengthInSeconds)
                )
                debugQueuePreloadSelection(prepared, source: "youtube-video")
                return prepared

            case .external(let track):
                let normalizedMediaID = track.mediaID.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !normalizedMediaID.isEmpty else { return nil }

                let payload: ExternalStreamPayload
                if let cachedPayload = externalPayloadCache[normalizedMediaID] {
                    payload = cachedPayload
                } else {
                    payload = try await track.resolvePayload()
                    externalPayloadCache[normalizedMediaID] = payload
                }

                let streamingService = Self.streamingService(for: payload.service)
                let candidate = PlaybackCandidate(
                    url: payload.streamURL,
                    streamKind: .audio,
                    mimeType: mimeTypeForCodecLabel(payload.codecLabel),
                    itag: nil,
                    expiresAt: nil,
                    isCompatible: true
                )
                let prepared = PreparedQueuePlayback(
                    mediaID: normalizedMediaID,
                    item: makePlayerItem(for: payload.streamURL, service: streamingService),
                    playbackCandidates: [candidate],
                    preparedAt: .now,
                    title: normalizedMusicDisplayTitle(payload.title, artist: payload.artist),
                    artist: normalizedMusicDisplayArtist(payload.artist, title: payload.title),
                    artworkURL: payload.artworkURL ?? track.artworkURL,
                    streamingService: streamingService,
                    qualityLabel: payload.qualityLabel,
                    codecLabel: payload.codecLabel,
                    albumName: nil,
                    isExplicit: track.isExplicit,
                    durationHint: nil
                )
                debugQueuePreloadSelection(prepared, source: "external-\(payload.service.rawValue)")
                return prepared
            }
        } catch {
            logPlayback("Queue preload failed for mediaID=\(entry.mediaID): \(error.localizedDescription)")
            return nil
        }
    }

    private func prepareMusicQueuePlayback(_ input: QueueMusicPreloadInput) async throws -> PreparedQueuePlayback? {
        let candidates = try await resolvePlaybackCandidates(forID: input.mediaID)
        guard let candidate = candidates.first else { return nil }

        let labels = playbackLabels(for: candidate)
        let prepared = PreparedQueuePlayback(
            mediaID: input.mediaID,
            item: makePlayerItem(for: candidate.url, service: .youtubeMusic),
            playbackCandidates: candidates,
            preparedAt: .now,
            title: normalizedMusicDisplayTitle(input.title, artist: input.artist),
            artist: normalizedMusicDisplayArtist(input.artist, title: input.title),
            artworkURL: input.artworkURL,
            streamingService: .youtubeMusic,
            qualityLabel: labels.quality,
            codecLabel: labels.codec,
            albumName: input.albumName,
            isExplicit: input.isExplicit,
            durationHint: input.durationHint
        )
        debugQueuePreloadSelection(prepared, source: input.youtubeDebugSource)
        return prepared
    }

    private func debugQueuePreloadSelection(_ prepared: PreparedQueuePlayback, source: String) {
#if DEBUG
        print("[QUEUE]: {source: \(source), mediaID: \(prepared.mediaID), title: \(prepared.title), artist: \(prepared.artist), service: \(prepared.streamingService.rawValue), quality: \(prepared.qualityLabel), codec: \(prepared.codecLabel), queueSource: \(queueSource.rawValue), queuePosition: \(queuePosition ?? -1), queueCount: \(queueCount)}")
#endif
    }
}
