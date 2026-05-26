//
//  PlayerViewModel+Queue.swift
//  cisum
//

import Foundation
import Models
import Services
import YouTubeSDK

extension PlayerViewModel {

    // MARK: - Queue Management

    func seedRadioQueue(from seedSong: YouTubeMusicSong) {
        let seedVideoID = seedSong.videoId
        radioSeedVideoID = seedVideoID
        radioAutoplayTask?.cancel()

        radioAutoplayTask = Task { @MainActor [weak self] in
            guard let self else { return }

            let cachedSession = self.radioSessionStore.session(forSeedVideoID: seedVideoID)
            if let cachedSession,
               self.shouldReuseCachedRadioSession(cachedSession),
               self.currentVideoId == seedVideoID {
                self.applyCachedRadioSession(cachedSession, fallbackSeed: seedSong)
                self.scheduleRadioContinuationIfNeeded()
                return
            }

            do {
                let radio = try await self.youtube.music.getRadio(videoId: seedVideoID)
                guard !Task.isCancelled, self.currentVideoId == seedVideoID else { return }

                self.radioPlaylistID = radio.playlistId
                self.radioContinuationToken = radio.continuationToken

                var tracks = self.buildSeededRadioTracks(seedSong: seedSong, radioItems: radio.items)
                tracks = await self.hydrateSeedRadioTracksIfNeeded(tracks, playlistID: self.radioPlaylistID)
                guard !Task.isCancelled, self.currentVideoId == seedVideoID else { return }

                self.applyRadioTracksToQueue(tracks, seedVideoID: seedVideoID)
                self.scheduleRadioContinuationIfNeeded()
            } catch {
                guard !Task.isCancelled else { return }
                if let cachedSession,
                   self.currentVideoId == seedVideoID,
                   !cachedSession.tracks.isEmpty {
                    self.applyCachedRadioSession(cachedSession, fallbackSeed: seedSong)
                    self.scheduleRadioContinuationIfNeeded()
                }
                self.logPlayback("Radio seed failed for id=\(seedVideoID): \(error.localizedDescription)")
            }
        }
    }

    func seedRadioQueueForExternalTrack(
        externalTrack: ExternalQueueTrack,
        resolvedPayload: ExternalStreamPayload,
        expectedCurrentMediaID: String
    ) {

        let title = normalizedMusicDisplayTitle(resolvedPayload.title, artist: resolvedPayload.artist)
        let artist = normalizedMusicDisplayArtist(resolvedPayload.artist, title: resolvedPayload.title)
        let query = radioSeedQuery(title: title, artist: artist)
        guard !query.isEmpty else { return }

        radioAutoplayTask?.cancel()
        radioAutoplayTask = Task { @MainActor [weak self] in
            guard let self else { return }
            guard self.currentVideoId == expectedCurrentMediaID else { return }

            do {
                let searchResults = try await self.youtube.music.search(query)
                guard !Task.isCancelled,
                      self.currentVideoId == expectedCurrentMediaID,
                      let seedSong = self.bestRadioSeedSong(
                        from: searchResults,
                        title: title,
                        artist: artist
                      ) else {
                    return
                }

                let seedVideoID = seedSong.videoId
                self.radioSeedVideoID = seedVideoID
                let leadingEntry = PlaybackQueueEntry.external(externalTrack)
                let cachedSession = self.radioSessionStore.session(forSeedVideoID: seedVideoID)

                if let cachedSession,
                   self.shouldReuseCachedRadioSession(cachedSession),
                   self.currentVideoId == expectedCurrentMediaID {
                    self.applyCachedRadioSession(
                        cachedSession,
                        fallbackSeed: seedSong,
                        leadingEntry: leadingEntry,
                        currentMediaID: expectedCurrentMediaID
                    )
                    self.scheduleRadioContinuationIfNeeded()
                    return
                }

                let radio = try await self.youtube.music.getRadio(videoId: seedVideoID)
                guard !Task.isCancelled, self.currentVideoId == expectedCurrentMediaID else { return }

                self.radioPlaylistID = radio.playlistId
                self.radioContinuationToken = radio.continuationToken

                var tracks = self.buildSeededRadioTracks(seedSong: seedSong, radioItems: radio.items)
                tracks = await self.hydrateSeedRadioTracksIfNeeded(tracks, playlistID: self.radioPlaylistID)
                guard !Task.isCancelled, self.currentVideoId == expectedCurrentMediaID else { return }

                self.applyRadioTracksToQueue(
                    tracks,
                    seedVideoID: seedVideoID,
                    leadingEntry: leadingEntry,
                    currentMediaID: expectedCurrentMediaID
                )
                self.scheduleRadioContinuationIfNeeded()
            } catch {
                guard !Task.isCancelled else { return }
                self.logPlayback("External radio seed failed for query=\(query): \(error.localizedDescription)")
            }
        }
    }

    func seedRadioQueueForVideoTrack(
        video: YouTubeVideo,
        expectedCurrentMediaID: String
    ) {
        let displayTitle = normalizedMusicDisplayTitle(video.title, artist: video.author)
        let displayArtist = normalizedMusicDisplayArtist(video.author, title: video.title)
        let query = radioSeedQuery(title: displayTitle, artist: displayArtist)
        let leadingEntry = PlaybackQueueEntry.video(video)

        radioAutoplayTask?.cancel()
        radioAutoplayTask = Task { @MainActor [weak self] in
            guard let self else { return }
            guard self.currentVideoId == expectedCurrentMediaID else { return }

            do {
                let radio = try await self.youtube.music.getRadio(videoId: video.id)
                guard !Task.isCancelled, self.currentVideoId == expectedCurrentMediaID else { return }

                self.radioPlaylistID = radio.playlistId
                self.radioContinuationToken = radio.continuationToken

                var tracks = self.buildSeededRadioTracks(seedSong: nil, radioItems: radio.items)
                tracks = await self.hydrateSeedRadioTracksIfNeeded(tracks, playlistID: self.radioPlaylistID)
                guard !Task.isCancelled, self.currentVideoId == expectedCurrentMediaID else { return }

                self.applyRadioTracksToQueue(
                    tracks,
                    seedVideoID: video.id,
                    leadingEntry: leadingEntry,
                    currentMediaID: expectedCurrentMediaID
                )
                self.scheduleRadioContinuationIfNeeded()
                return
            } catch {
                self.logPlayback("Video direct radio seed failed for id=\(video.id): \(error.localizedDescription)")
            }

            guard !query.isEmpty else { return }

            do {
                let searchResults = try await self.youtube.music.search(query)
                guard !Task.isCancelled,
                      self.currentVideoId == expectedCurrentMediaID,
                      let seedSong = self.bestRadioSeedSong(
                        from: searchResults,
                        title: displayTitle,
                        artist: displayArtist
                      ) else {
                    return
                }

                let seedVideoID = seedSong.videoId
                self.radioSeedVideoID = seedVideoID
                let cachedSession = self.radioSessionStore.session(forSeedVideoID: seedVideoID)

                if let cachedSession,
                   self.shouldReuseCachedRadioSession(cachedSession),
                   self.currentVideoId == expectedCurrentMediaID {
                    self.applyCachedRadioSession(
                        cachedSession,
                        fallbackSeed: seedSong,
                        leadingEntry: leadingEntry,
                        currentMediaID: expectedCurrentMediaID
                    )
                    self.scheduleRadioContinuationIfNeeded()
                    return
                }

                let radio = try await self.youtube.music.getRadio(videoId: seedVideoID)
                guard !Task.isCancelled, self.currentVideoId == expectedCurrentMediaID else { return }

                self.radioPlaylistID = radio.playlistId
                self.radioContinuationToken = radio.continuationToken

                var tracks = self.buildSeededRadioTracks(seedSong: seedSong, radioItems: radio.items)
                tracks = await self.hydrateSeedRadioTracksIfNeeded(tracks, playlistID: self.radioPlaylistID)
                guard !Task.isCancelled, self.currentVideoId == expectedCurrentMediaID else { return }

                self.applyRadioTracksToQueue(
                    tracks,
                    seedVideoID: seedVideoID,
                    leadingEntry: leadingEntry,
                    currentMediaID: expectedCurrentMediaID
                )
                self.scheduleRadioContinuationIfNeeded()
            } catch {
                guard !Task.isCancelled else { return }
                self.logPlayback("Video metadata radio seed failed for query=\(query): \(error.localizedDescription)")
            }
        }
    }

    func radioSeedQuery(title: String, artist: String) -> String {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)

        if !normalizedTitle.isEmpty && !normalizedArtist.isEmpty {
            return "\(normalizedTitle) \(normalizedArtist)"
        }
        if !normalizedTitle.isEmpty {
            return normalizedTitle
        }
        return normalizedArtist
    }

    func bestRadioSeedSong(from candidates: [YouTubeMusicSong], title: String, artist: String) -> YouTubeMusicSong? {
        guard !candidates.isEmpty else { return nil }

        let targetTitle = title.lowercased()
        let targetArtist = artist.lowercased()

        return candidates.max { lhs, rhs in
            let lhsTitle = normalizedMusicDisplayTitle(lhs.title, artist: lhs.artistsDisplay).lowercased()
            let rhsTitle = normalizedMusicDisplayTitle(rhs.title, artist: rhs.artistsDisplay).lowercased()
            let lhsArtist = normalizedMusicDisplayArtist(lhs.artistsDisplay, title: lhs.title).lowercased()
            let rhsArtist = normalizedMusicDisplayArtist(rhs.artistsDisplay, title: rhs.title).lowercased()

            let lhsScore = (0.7 * tokenOverlapScore(lhsTitle, targetTitle)) + (0.3 * tokenOverlapScore(lhsArtist, targetArtist))
            let rhsScore = (0.7 * tokenOverlapScore(rhsTitle, targetTitle)) + (0.3 * tokenOverlapScore(rhsArtist, targetArtist))
            return lhsScore < rhsScore
        }
    }

    func shouldReuseCachedRadioSession(_ session: RadioSessionStore.Session) -> Bool {
        let validTrackCount = session.tracks.compactMap { CachedRadioTrack(cached: $0) }.count
        if validTrackCount == 0 {
            return false
        }
        return validTrackCount >= 8 // RadioAutoplayPolicy.minCachedTracksWithoutContinuation
    }

    func hydrateSeedRadioTracksIfNeeded(
        _ tracks: [CachedRadioTrack],
        playlistID: String?
    ) async -> [CachedRadioTrack] {
        guard tracks.count < 16 else { // RadioAutoplayPolicy.minSeedTracksBeforePlaylistHydration
            return tracks
        }

        guard let playlistID = playlistID?.trimmingCharacters(in: .whitespacesAndNewlines),
              !playlistID.isEmpty else {
            return tracks
        }

        do {
            let queueItems = try await youtube.music.getQueue(playlistId: playlistID)
            guard !queueItems.isEmpty else { return tracks }

            var merged = tracks
            var knownIDs = Set(merged.map(\.videoID))
            for song in queueItems {
                let track = CachedRadioTrack(song: song)
                guard knownIDs.insert(track.videoID).inserted else { continue }
                merged.append(track)
                if merged.count >= 80 { // RadioAutoplayPolicy.maxSeedQueueTracks
                    break
                }
            }

            if merged.count > tracks.count {
                logPlayback("Radio seed hydrated from playlist: +\(merged.count - tracks.count) track(s)")
            }

            return merged
        } catch {
            logPlayback("Radio seed hydration failed for playlistID=\(playlistID): \(error.localizedDescription)")
            return tracks
        }
    }

    func clearRadioAutoplayState() {
        radioAutoplayTask?.cancel()
        radioAutoplayTask = nil
        radioContinuationTask?.cancel()
        radioContinuationTask = nil
        radioSeedVideoID = nil
        radioPlaylistID = nil
        radioContinuationToken = nil
        isLoadingRadioContinuation = false
    }

    func applyCachedRadioSession(
        _ session: RadioSessionStore.Session,
        fallbackSeed: YouTubeMusicSong,
        leadingEntry: PlaybackQueueEntry? = nil,
        currentMediaID: String? = nil
    ) {
        let cachedTracks = session.tracks.compactMap { CachedRadioTrack(cached: $0) }
        guard !cachedTracks.isEmpty else { return }

        var mappedTracks = cachedTracks
        let seedID = session.seedVideoID

        if let first = mappedTracks.first, first.videoID == seedID {
            mappedTracks.removeFirst()
        }
        if mappedTracks.isEmpty {
            mappedTracks = [CachedRadioTrack(song: fallbackSeed)]
        }

        radioPlaylistID = session.playlistID
        radioContinuationToken = session.continuationToken

        applyRadioTracksToQueue(
            mappedTracks,
            seedVideoID: seedID,
            leadingEntry: leadingEntry,
            currentMediaID: currentMediaID
        )
    }

    func applyRadioTracksToQueue(
        _ tracks: [CachedRadioTrack],
        seedVideoID: String,
        leadingEntry: PlaybackQueueEntry? = nil,
        currentMediaID: String? = nil
    ) {
        guard !tracks.isEmpty else { return }

        var entries = tracks.map { PlaybackQueueEntry.cachedRadio($0) }
        if let leadingEntry {
            entries.insert(leadingEntry, at: 0)
        } else if queueSource == .radioAutoplay {
            if playbackQueue.indices.contains(queuePosition ?? 0) {
                entries.insert(playbackQueue[queuePosition ?? 0], at: 0)
            }
        }

        playbackQueue = entries
        queueCount = entries.count
        queueSource = .radioAutoplay
        queuePosition = 0

        let expectedMediaID = currentMediaID ?? seedVideoID
        if expectedMediaID == self.currentVideoId {
            logPlayback("Successfully seeded radio for \(expectedMediaID) with \(tracks.count) tracks")
        }

        let serializableTracks = tracks.map { $0.persisted }
        let session = RadioSessionStore.Session(
            seedVideoID: seedVideoID,
            playlistID: radioPlaylistID,
            continuationToken: radioContinuationToken,
            tracks: serializableTracks
        )
        radioSessionStore.save(session: session)
    }

    func scheduleRadioContinuationIfNeeded() {
        guard let token = radioContinuationToken, !token.isEmpty else { return }
        guard queueSource == .radioAutoplay else { return }
        
        let remaining = queueCount - (queuePosition ?? 0)
        guard remaining <= 5 else { return } // RadioAutoplayPolicy.queueLowWatermark

        guard !isLoadingRadioContinuation else { return }
        fetchRadioContinuation(token: token)
    }

    func fetchRadioContinuation(token: String) {
        isLoadingRadioContinuation = true
        radioContinuationTask?.cancel()
        radioContinuationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.isLoadingRadioContinuation = false }

            do {
                let radio = try await self.youtube.music.getRadioContinuation(token: token)
                guard !Task.isCancelled else { return }

                self.radioContinuationToken = radio.continuationToken
                let newTracks = self.buildSeededRadioTracks(seedSong: nil, radioItems: radio.items)
                
                guard !newTracks.isEmpty else { return }

                let entries = newTracks.map { PlaybackQueueEntry.cachedRadio($0) }
                self.playbackQueue.append(contentsOf: entries)
                self.queueCount = self.playbackQueue.count
                
                if let seedID = self.radioSeedVideoID {
                    let cachedTracks = newTracks.map { $0.persisted }
                    if let existingSession = self.radioSessionStore.session(forSeedVideoID: seedID) {
                        let mergedTracks = existingSession.tracks + cachedTracks
                        let newSession = RadioSessionStore.Session(
                            seedVideoID: seedID,
                            playlistID: existingSession.playlistID,
                            continuationToken: self.radioContinuationToken,
                            tracks: mergedTracks
                        )
                        self.radioSessionStore.save(session: newSession)
                    }
                }
                
                self.logPlayback("Appended \(newTracks.count) tracks via radio continuation")
                
            } catch {
                guard !Task.isCancelled else { return }
                self.logPlayback("Radio continuation failed: \(error.localizedDescription)")
            }
        }
    }

    func buildSeededRadioTracks(seedSong: YouTubeMusicSong?, radioItems: [YouTubeMusicSong]) -> [CachedRadioTrack] {
        var tracks = radioItems.map { CachedRadioTrack(song: $0) }
        
        let seedID = seedSong?.videoId ?? radioSeedVideoID
        if let seedID, let first = tracks.first, first.videoID == seedID {
            tracks.removeFirst()
        }
        
        if tracks.isEmpty, let seedSong {
            tracks = [CachedRadioTrack(song: seedSong)]
        }
        
        return tracks
    }
}
