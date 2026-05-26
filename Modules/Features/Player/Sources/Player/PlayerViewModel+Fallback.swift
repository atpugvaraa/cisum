//
//  PlayerViewModel+Fallback.swift
//  cisum
//

import Foundation
import Models
import Services
import ProviderSDK
import AVFoundation
import YouTubeSDK

extension PlayerViewModel {

    // MARK: - Playback Resolution & Fallback

    func resolvePlaybackCandidates(forID id: String, title: String = "", artist: String = "", forceDecipher: Bool = false) async throws -> [PlaybackCandidate] {
        let normalizedID = canonicalPlaybackMediaID(id)
        let resolver = await PlaybackURLResolver.sharedInstance()
        return try await resolver.resolve(mediaID: normalizedID, title: title, artist: artist, forceDecipher: forceDecipher)
    }

    func resolvePrioritizedPlaybackCandidates(
        mediaID: String,
        title: String,
        artist: String
    ) async throws -> PrioritizedCandidateResolution {
        let youtubeCandidates = try await resolvePlaybackCandidates(
            forID: mediaID,
            title: title,
            artist: artist
        )
        return PrioritizedCandidateResolution(candidates: youtubeCandidates, hiResPayload: nil)
    }

    func makePlayerItem(for url: URL, headers: [String: String]? = nil, service: StreamingService? = nil) -> AVPlayerItem {
        let resolvedService: StreamingService = service ?? (StreamingService(rawValue: currentStreamingServiceName) ?? .youtubeMusic)

        if resolvedService == .youtube || resolvedService == .youtubeMusic {
            logPlayback("Using direct AVPlayerItem load for YouTube host=\(url.host ?? "unknown")")
        } else {
            logPlayback("Using plain AVPlayerItem load host=\(url.host ?? "unknown")")
        }

        let ua = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15"
        let host = url.host ?? ""
        
        if host.contains("googlevideo.com") || url.absoluteString.contains("manifest") {
            let proxyURL = url.proxyURL ?? url
            let nSolver = YouTubeWebViewHLSExtractor.shared.extractedNSolver
            let proxyLoader = YTHLSProxyLoader(ua: ua, nSolver: nSolver)
            let asset = AVURLAsset(url: proxyURL)
            asset.resourceLoader.setDelegate(proxyLoader, queue: DispatchQueue.global(qos: .userInitiated))
            
            // Keep reference to prevent ARC release
            self.webHLSProxyLoader = proxyLoader
            
            return AVPlayerItem(asset: asset)
        }

        if let headers = headers, !headers.isEmpty {
            let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
            return AVPlayerItem(asset: asset)
        }
        
        return AVPlayerItem(url: url)
    }

    func mimeTypeForCodecLabel(_ codecLabel: String) -> String? {
        let normalized = codecLabel.lowercased()
        if normalized.contains("flac") { return "audio/flac" }
        if normalized.contains("aac") { return "audio/aac" }
        if normalized.contains("mp3") { return "audio/mpeg" }
        if normalized.contains("hls") { return "application/x-mpegURL" }
        return nil
    }

    func updateAudioFormatLabels(for candidate: PlaybackCandidate) {
        if let pendingPlaybackFormatOverride {
            currentAudioQualityLabel = pendingPlaybackFormatOverride.quality
            currentAudioCodecLabel = pendingPlaybackFormatOverride.codec
            self.pendingPlaybackFormatOverride = nil
            return
        }

        let labels = playbackLabels(for: candidate)
        currentAudioQualityLabel = labels.quality
        currentAudioCodecLabel = labels.codec
    }

    func configurePlaybackCandidates(for mediaID: String, candidates: [PlaybackCandidate]) {
        playbackCandidatesMediaID = mediaID
        playbackCandidates = candidates
        playbackCandidateIndex = 0
    }
    
    func attemptNextPlaybackCandidateIfAvailable(errorMessage: String) -> Bool {
        guard let currentMediaID = currentVideoId,
              currentMediaID == playbackCandidatesMediaID,
              !playbackCandidates.isEmpty,
              playbackCandidateIndex + 1 < playbackCandidates.count else {
            return false
        }

        playbackCandidateIndex += 1
        let nextCandidate = playbackCandidates[playbackCandidateIndex]
        logPlayback("Fallback triggered: index=\(playbackCandidateIndex) total=\(playbackCandidates.count) url=\(nextCandidate.url.absoluteString)")

        let position = currentTime > 1 ? currentTime : nil

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.savedPositionToRestore = position
            self.playCurrentPlaybackCandidate()
        }
        return true
    }

    func handlePlaybackPermissionFailureIfNeeded(
        errorMessage: String,
        statusCode: Int?,
        errorDomain: String?,
        errorCode: Int?
    ) -> Bool {
        guard let mediaID = currentVideoId else { return false }
        guard supportsYouTubeCandidateRecovery else { return false }

        guard shouldAttemptPlaybackRecovery(
            for: errorMessage,
            statusCode: statusCode,
            errorDomain: errorDomain,
            errorCode: errorCode
        ) else {
            return false
        }

        let currentAttemptCount = playbackRecoveryAttemptCounts[mediaID, default: 0]
        guard currentAttemptCount < PlaybackRecoveryPolicy.maxAttemptsPerMediaID else {
            return false
        }

        playbackRecoveryAttemptCounts[mediaID] = currentAttemptCount + 1
        playbackRecoveryTask?.cancel()
        playbackRecoveryTask = Task { [weak self] in
            guard let self else { return }

            do {
                await self.metadataCache.remove(mediaID)
                self.mediaCacheStore.invalidatePlayback(for: mediaID)
                let candidates = try await self.resolvePlaybackCandidates(
                    forID: mediaID,
                    title: self.currentTitle,
                    artist: self.currentArtist,
                    forceDecipher: true
                )

                guard !Task.isCancelled, self.currentVideoId == mediaID else { return }
                self.configurePlaybackCandidates(for: mediaID, candidates: candidates)
                self.playCurrentPlaybackCandidate()
                self.logPlayback(
                    "Recovered playback with refreshed stream URL for id=\(mediaID), attempt=\(currentAttemptCount + 1), status=\(statusCode.map(String.init) ?? "n/a")"
                )
            } catch {
                guard !Task.isCancelled, self.currentVideoId == mediaID else { return }
                self.playbackEngine.setIsPlaying(false)
                self.playbackError = error.localizedDescription
                self.updateNowPlayingPlaybackInfo(force: true)
                self.updateRemoteCommandState()
                print("❌ PlayerViewModel: Playback recovery failed for id=\(mediaID): \(error.localizedDescription)")
            }
        }

        return true
    }

    private func shouldAttemptPlaybackRecovery(
        for errorMessage: String,
        statusCode: Int?,
        errorDomain: String?,
        errorCode: Int?
    ) -> Bool {
        if let statusCode {
            if statusCode == 401 || statusCode == 403 || statusCode == 404 || statusCode == 410 || statusCode == 429 {
                return true
            }

            if statusCode >= 500 {
                return true
            }
        }

        if let errorDomain,
            let errorCode,
            errorDomain == NSURLErrorDomain {
            let recoverableCodes: Set<Int> = [-1100, -1102, -1011, -1009, -1005, -1004, -1003, -1001]
            if recoverableCodes.contains(errorCode) {
                return true
            }
        }

        if let errorDomain,
            let errorCode,
            errorDomain == AVFoundationErrorDomain {
            let recoverableCodes: Set<Int> = [-11800, -11819, -11850, -11867]
            if recoverableCodes.contains(errorCode) {
                return true
            }
        }

        let normalized = errorMessage.lowercased()
        return normalized.contains("permission")
            || normalized.contains("forbidden")
            || normalized.contains("403")
            || normalized.contains("not authorized")
            || normalized.contains("access denied")
            || normalized.contains("expired")
            || normalized.contains("signature")
            || normalized.contains("token")
            || normalized == "unknown error"
            || normalized.contains("failed to load")
            || normalized.contains("could not be loaded")
    }

    func advanceQueueAfterUnrecoverableFailure(errorMessage: String) -> Bool {
        guard hasNextTrackInQueue else {
            return false
        }

        logPlayback("Advancing queue after unrecoverable failure: \(errorMessage)")
        advanceToNextQueueEntry(triggeredByPlaybackEnd: true)
        return true
    }

    func handlePlaybackFailure(_ error: Error) {
        playbackEngine.pause()
        playbackError = error.localizedDescription
        updateNowPlayingPlaybackInfo(force: true)
        updateRemoteCommandState()
        
        let videoID = currentVideoId ?? "Unknown"
        print("❌ PlayerViewModel: Playback failed for ID [\(videoID)]: \(error.localizedDescription)")
    }
}