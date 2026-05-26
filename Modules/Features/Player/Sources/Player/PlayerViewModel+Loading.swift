//
//  PlayerViewModel+Loading.swift
//  cisum
//

import Foundation
import Models
import Services
import ProviderSDK
import YouTubeSDK

extension PlayerViewModel {

    // MARK: - Loaders

    public func load(external track: ExternalQueueTrack, preserveQueue: Bool = false) {
        loadExternalTrack(track, preserveQueue: preserveQueue)
    }

    public func setQueue(_ tracks: [ExternalQueueTrack], startIndex: Int = 0) {
        guard !tracks.isEmpty else { return }
        let entries = tracks.map { PlaybackQueueEntry.external($0) }
        playbackQueue = entries
        queueCount = entries.count
        queueSource = .userQueue
        queuePosition = startIndex
        if entries.indices.contains(startIndex) {
            load(entry: entries[startIndex])
        }
    }

    public func load(song: YouTubeMusicSong, preserveQueue: Bool = false) {
        // Patch 3: Skip if we are already actively loading this exact track.
        if song.videoId == loadingMediaID, isLoading { return }

        loadMusicTrack(
            mediaID: song.videoId,
            title: song.title,
            artist: song.artistsDisplay,
            albumName: song.album,
            thumbnailURL: song.thumbnailURL,
            explicit: song.isExplicit,
            durationHint: Self.lyricsDurationHint(from: song.duration),
            preserveQueue: preserveQueue
        )

        if !preserveQueue {
            seedRadioQueue(from: song)
        }
    }

    public func load(video: YouTubeVideo, preserveQueue: Bool = false) {
        // Patch 3
        if video.id == loadingMediaID, isLoading { return }
        let targetMediaID = video.id

        let tapStartedAt = Date()
        let fallbackURL = normalizedArtworkURL(from: video.thumbnailURL)
        let displayTitle = normalizedMusicDisplayTitle(video.title, artist: video.author)
        let displayArtist = normalizedMusicDisplayArtist(video.author, title: video.title)

        let presentation = TrackPresentationState(
            mediaID: targetMediaID,
            title: displayTitle,
            artist: displayArtist,
            albumName: nil,
            artworkURL: fallbackURL,
            isExplicit: false,
            streamingService: .youtube,
            qualityLabel: "Resolving...",
            codecLabel: "Resolving...",
            durationHint: Self.lyricsDurationHint(from: video.lengthInSeconds),
            queueIdentity: makeQueueIdentitySnapshot(
                mediaID: targetMediaID,
                title: displayTitle,
                artist: displayArtist,
                activeRepresentationKey: nil,
                hydrationState: ["metadataResolved"],
                candidateSnapshot: []
            )
        )
        preparePlaybackSession(for: presentation, preserveQueue: preserveQueue)

        isLoading = true
        loadingMediaID = targetMediaID
        currentLoadTask?.cancel()
        currentLoadTask = Task { [weak self] in
            guard let self = self else { return }
            defer { if self.loadingMediaID == targetMediaID { self.isLoading = false } }
            if Task.isCancelled { return }

            do {
                let candidates = try await self.resolvePlaybackCandidates(
                    forID: video.id,
                    title: video.title ?? "",
                    artist: video.author ?? ""
                )

                if Task.isCancelled { return }
                guard self.currentVideoId == targetMediaID else { return }

                self.configurePlaybackCandidates(for: video.id, candidates: candidates)
                self.playCurrentPlaybackCandidate()
                self.startArtworkVideoProcessingIfNeeded(
                    for: video.id,
                    title: displayTitle,
                    artist: displayArtist,
                    albumName: nil
                )
                self.logPlayback("Started playback for video id=\(video.id)")

                if !preserveQueue {
                    self.seedRadioQueueForVideoTrack(
                        video: video,
                        expectedCurrentMediaID: targetMediaID
                    )
                }

                self.preloadNextQueueEntryIfNeeded()

                if self.settings.metricsEnabled {
                    let elapsed = Date().timeIntervalSince(tapStartedAt) * 1000
                    await self.playbackMetricsStore.recordTapToPlay(durationMs: elapsed)
                }
            } catch {
                if error is CancellationError { return }
                guard self.currentVideoId == targetMediaID else { return }
                self.handlePlaybackFailure(error)
            }
        }
    }

    public func load(resolvedPlaybackSession session: ResolvedPlaybackSession, preserveQueue: Bool = false) {
        let track = session.playableTrack.track
        let title = track.title
        let artist = track.artists.map(\.name).joined(separator: ", ")
        let albumName = track.album.title
        let activeCandidate = session.selectedCandidate
        let hydrationLabels: [String] = [
            track.hydrationState.contains(.metadataResolved) ? "metadataResolved" : nil,
            track.hydrationState.contains(.artworkResolved) ? "artworkResolved" : nil,
            track.hydrationState.contains(.streamResolved) ? "streamResolved" : nil,
            track.hydrationState.contains(.lyricsResolved) ? "lyricsResolved" : nil
        ].compactMap { $0 }
        let representationKey = track.activeRepresentationKey.map { "\($0.providerID):\($0.providerTrackID)" }

        let presentation = TrackPresentationState(
            mediaID: track.id.value,
            title: title,
            artist: artist,
            albumName: albumName,
            artworkURL: track.externalURL,
            isExplicit: track.isExplicit,
            streamingService: .external,
            qualityLabel: session.stream.quality.displayName,
            codecLabel: session.stream.codec.formatDescription,
            durationHint: Int(track.duration),
            queueIdentity: makeQueueIdentitySnapshot(
                mediaID: track.id.value,
                title: title,
                artist: artist,
                activeRepresentationKey: representationKey,
                hydrationState: hydrationLabels,
                candidateSnapshot: [
                    QueueCandidateSnapshot(
                        streamKind: session.stream.provider,
                        mimeType: session.stream.metadata["mimeType"],
                        itag: nil,
                        expiresAt: session.stream.expiresAt,
                        isCompatible: activeCandidate.isLocal
                    )
                ]
            )
        )

        preparePlaybackSession(for: presentation, preserveQueue: preserveQueue)

        let localCandidate = PlaybackCandidate(
            url: session.stream.url,
            streamKind: .audio,
            mimeType: session.stream.metadata["mimeType"] ?? session.stream.codec.formatDescription,
            itag: nil,
            expiresAt: session.stream.expiresAt,
            isCompatible: true
        )

        configurePlaybackCandidates(for: track.id.value, candidates: [localCandidate])
        playCurrentPlaybackCandidate()
    }

    func loadMusicTrack(
        mediaID: String,
        title: String,
        artist: String,
        albumName: String?,
        thumbnailURL: URL?,
        explicit: Bool,
        durationHint: Int?,
        preserveQueue: Bool
    ) {
        let targetMediaID = mediaID

        let tapStartedAt = Date()
        let displayTitle = normalizedMusicDisplayTitle(title, artist: artist)
        let displayArtist = normalizedMusicDisplayArtist(artist, title: title)

        let presentation = TrackPresentationState(
            mediaID: mediaID,
            title: displayTitle,
            artist: displayArtist,
            albumName: albumName,
            artworkURL: thumbnailURL,
            isExplicit: explicit,
            streamingService: .youtube,
            qualityLabel: "Resolving...",
            codecLabel: "Resolving...",
            durationHint: durationHint,
            queueIdentity: makeQueueIdentitySnapshot(
                mediaID: mediaID,
                title: displayTitle,
                artist: displayArtist,
                activeRepresentationKey: nil,
                hydrationState: ["metadataResolved"],
                candidateSnapshot: []
            )
        )
        preparePlaybackSession(for: presentation, preserveQueue: preserveQueue)

        isLoading = true
        loadingMediaID = targetMediaID
        currentLoadTask?.cancel()
        currentLoadTask = Task { [weak self] in
            guard let self = self else { return }
            defer { if self.loadingMediaID == targetMediaID { self.isLoading = false } }
            if Task.isCancelled { return }

            do {
                // Resolve YouTube candidates and start playback immediately.
                let youtubeCandidates = try await self.resolvePlaybackCandidates(
                    forID: mediaID,
                    title: title,
                    artist: artist
                )

                if Task.isCancelled { return }
                guard self.currentVideoId == targetMediaID else { return }

                self.configurePlaybackCandidates(for: mediaID, candidates: youtubeCandidates)
                self.playCurrentPlaybackCandidate()
                self.startArtworkVideoProcessingIfNeeded(
                    for: mediaID,
                    title: self.currentTitle,
                    artist: self.currentArtist,
                    albumName: albumName
                )
                self.logPlayback("Started playback for song id=\(mediaID)")
                self.preloadNextQueueEntryIfNeeded()

                if self.settings.metricsEnabled {
                    let elapsed = Date().timeIntervalSince(tapStartedAt) * 1000
                    await self.playbackMetricsStore.recordTapToPlay(durationMs: elapsed)
                }

            } catch {
                if error is CancellationError { return }
                guard self.currentVideoId == targetMediaID else { return }
                self.handlePlaybackFailure(error)
            }
        }
    }


    public func loadExternalStream(
        mediaID: String,
        streamURL: URL,
        title: String,
        artist: String,
        artworkURL: URL?,
        service: FederatedService,
        qualityLabel: String,
        codecLabel: String
    ) {
        let immediateTrack = ExternalQueueTrack(
            mediaID: mediaID,
            title: title,
            artist: artist,
            artworkURL: artworkURL,
            service: service,
            isExplicit: false,
            qualityLabelHint: qualityLabel,
            codecLabelHint: codecLabel,
            resolvePayload: {
                ExternalStreamPayload(
                    mediaID: mediaID,
                    streamURL: streamURL,
                    title: title,
                    artist: artist,
                    artworkURL: artworkURL,
                    service: service,
                    qualityLabel: qualityLabel,
                    codecLabel: codecLabel
                )
            }
        )

        loadExternalTrack(immediateTrack, preserveQueue: false)
    }

}
