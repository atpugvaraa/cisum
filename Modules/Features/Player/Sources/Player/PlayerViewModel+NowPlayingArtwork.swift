import Utilities
import Foundation
import MediaPlayer
import SwiftUI

#if os(iOS)
import AVFoundation
import UIKit

#if canImport(iTunesKit)
import iTunesKit
#endif

#endif

@MainActor
extension PlayerViewModel {
    struct MotionArtworkSourceResolution {
        let sourceHLSURL: URL
        let videoCacheID: String
    }


#if os(iOS)
    struct NowPlayingState: Equatable {
        var mediaID: String?
        var title: String = "Not Playing"
        var artist: String = ""
        var artworkURL: URL?
        var duration: Double = 0
        var elapsedTime: Double = 0
        var playbackRate: Float = 0
    }

    struct CachedNowPlayingArtworkResource {
        let url: URL
        let data: Data
        let size: CGSize
    }

    func updateNowPlayingMetadata(force: Bool = true) {
        nowPlayingState.mediaID = currentVideoId
        nowPlayingState.title = currentTitle
        nowPlayingState.artist = currentArtist
        nowPlayingState.artworkURL = currentImageURL
        updateNowPlayingPlaybackInfo(force: force)
    }

    func updateNowPlayingPlaybackInfo(force: Bool = false) {
        nowPlayingState.elapsedTime = currentElapsedTimeSnapshot()
        nowPlayingState.duration = currentDurationSnapshot()
        nowPlayingState.playbackRate = currentPlaybackRateSnapshot()

        publishNowPlayingInfo(force: force)
    }

    func loadNowPlayingArtwork(for mediaID: String, title: String, artist: String, fallbackURL: URL?) {
        artworkLoadTask?.cancel()

        let artworkTitle = normalizedMusicDisplayTitle(title, artist: artist)
        let artworkArtist = normalizedMusicDisplayArtist(artist, title: title)
        let fallbackArtworkURL = fallbackURL

        artworkLoadTask = Task { [weak self] in
            guard let self else { return }
            #if canImport(iTunesKit)
            let itunes = self.itunes
            #endif
            if Task.isCancelled { return }

            if let persistedArtwork = await self.loadPersistentArtworkIfAvailable(for: mediaID) {
                guard self.currentVideoId == mediaID else { return }
                self.applyArtwork(persistedArtwork, for: mediaID, cacheInMemory: true)
                self.updateNowPlayingMetadata(force: true)
                return
            }

            let fallbackTask = Task {
                await Self.fetchArtworkResource(from: fallbackArtworkURL)
            }
            let highQualityTask = Task<CachedNowPlayingArtworkResource?, Never> {
                if let cachedURL = self.mediaCacheStore.cachedHighQualityArtworkURL(
                    for: mediaID,
                    maxAge: CachePolicy.highQualityArtworkTTL
                ) {
                    if let cachedArtwork = await Self.fetchArtworkResource(from: cachedURL) {
                        return cachedArtwork
                    }
                }

                #if canImport(iTunesKit)
                if let highQualityURL = await Self.resolveHighQualityArtworkURL(
                    using: itunes,
                    title: artworkTitle,
                    artist: artworkArtist
                ) {
                    self.mediaCacheStore.saveHighQualityArtworkURL(highQualityURL, for: mediaID)
                    return await Self.fetchArtworkResource(from: highQualityURL)
                }
                #endif

                return nil
            }

            if let fallbackArtwork = await fallbackTask.value {
                guard self.currentVideoId == mediaID else { return }
                guard self.currentArtworkMediaID != mediaID else { return }

                self.applyArtwork(fallbackArtwork, for: mediaID, cacheInMemory: false)
                self.updateNowPlayingMetadata(force: true)
                await self.persistArtwork(fallbackArtwork, mediaID: mediaID)
            }

            if let highQualityArtwork = await highQualityTask.value {
                guard self.currentVideoId == mediaID else { return }

                self.applyArtwork(highQualityArtwork, for: mediaID, cacheInMemory: true)
                self.updateNowPlayingMetadata(force: true)
                await self.persistArtwork(highQualityArtwork, mediaID: mediaID)
            }
        }
    }

    private func currentElapsedTimeSnapshot() -> Double {
        max(currentTime, 0)
    }

    private func currentDurationSnapshot() -> Double {
        guard duration.isFinite, !duration.isNaN else {
            return 0
        }

        return max(duration, 0)
    }

    private func currentPlaybackRateSnapshot() -> Float {
        isPlaying ? max(player.rate, 1) : 0
    }

    private func publishNowPlayingInfo(force: Bool) {
        if !force, let lastPublishedNowPlayingState {
            let elapsedChangedEnough = abs(lastPublishedNowPlayingState.elapsedTime - nowPlayingState.elapsedTime) >= 0.5
            let metadataChanged = lastPublishedNowPlayingState.mediaID != nowPlayingState.mediaID
                || lastPublishedNowPlayingState.title != nowPlayingState.title
                || lastPublishedNowPlayingState.artist != nowPlayingState.artist
                || lastPublishedNowPlayingState.artworkURL != nowPlayingState.artworkURL
                || abs(lastPublishedNowPlayingState.duration - nowPlayingState.duration) >= 0.001
                || abs(Double(lastPublishedNowPlayingState.playbackRate - nowPlayingState.playbackRate)) >= 0.001

            guard elapsedChangedEnough || metadataChanged else {
                return
            }
        }

        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPMediaItemPropertyTitle] = nowPlayingState.title
        info[MPMediaItemPropertyArtist] = nowPlayingState.artist
        info[MPMediaItemPropertyPlaybackDuration] = nowPlayingState.duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = nowPlayingState.elapsedTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = nowPlayingState.playbackRate

        if let currentArtworkResource,
           let mediaItemArtwork = Self.makeMediaItemArtwork(from: currentArtworkResource) {
            info[MPMediaItemPropertyArtwork] = mediaItemArtwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info

        if #available(iOS 13.0, *) {
            MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
        }

        lastPublishedNowPlayingState = nowPlayingState
    }

    func applyCachedArtworkIfAvailable(for mediaID: String) {
        guard let cachedArtwork = artworkCache[mediaID] else {
            currentArtworkResource = nil
            currentArtworkMediaID = nil
            return
        }

        applyArtwork(cachedArtwork, for: mediaID, cacheInMemory: false)
    }

    private func applyArtwork(
        _ artwork: CachedNowPlayingArtworkResource,
        for mediaID: String,
        cacheInMemory: Bool
    ) {
        currentImageURL = artwork.url
        currentArtworkResource = artwork
        currentArtworkMediaID = mediaID
        updateAccentColor(from: artwork, mediaID: mediaID)

        if cacheInMemory {
            artworkCache[mediaID] = artwork
        }
    }

    private func updateAccentColor(from artwork: CachedNowPlayingArtworkResource, mediaID: String) {
        if let cachedAccent = artworkAccentCache[mediaID],
           cachedAccent.artworkURL == artwork.url {
            applyAccentColor(cachedAccent.color)
            return
        }

        accentLoadTask?.cancel()
        let artworkData = artwork.data
        let artworkURL = artwork.url

        accentLoadTask = Task { @MainActor [weak self] in
            guard let self else { return }

            let extractedPalette = await artworkColorExtractor.extractPalette(from: artworkData, cacheKey: artworkURL.absoluteString)

            guard !Task.isCancelled else { return }
            guard self.currentVideoId == mediaID else { return }

            self.artworkPaletteCache[mediaID] = (artworkURL: artworkURL, palette: extractedPalette)
            self.applyAccentColor(extractedPalette?.dominant ?? .accentColor)
        }
    }

    private func applyAccentColor(_ color: Color) {
        currentAccentColor = color
        Color.updateDynamicAccent(color)
    }

    private func loadPersistentArtworkIfAvailable(for mediaID: String) async -> CachedNowPlayingArtworkResource? {
        guard let cachedArtwork = await mediaCacheStore.cachedLocalArtworkData(for: mediaID),
              let image = UIImage(data: cachedArtwork.data) else {
            return nil
        }

        return CachedNowPlayingArtworkResource(
            url: cachedArtwork.url,
            data: cachedArtwork.data,
            size: image.size
        )
    }

    private func persistArtwork(_ artwork: CachedNowPlayingArtworkResource, mediaID: String) async {
        _ = await mediaCacheStore.saveArtworkData(
            artwork.data,
            mediaID: mediaID,
            sourceURL: artwork.url
        )
    }

    #if canImport(iTunesKit)
    nonisolated private static func resolveHighQualityArtworkURL(using itunes: iTunesKit, title: String, artist: String) async -> URL? {
        do {
            let searchTitle = normalizedMusicDisplayTitle(title, artist: artist)
            let searchArtist = normalizedMusicDisplayArtist(artist, title: title)
            let response = try await itunes.search(term: "\(searchTitle) \(searchArtist)", country: "us", media: "music", limit: 1)
            return normalizedITunesArtworkURL(from: response.results.first?.artworkUrl100)
        } catch {
            return nil
        }
    }
    #endif

    func resolveMotionArtworkSource(
        for mediaID: String,
        title: String,
        artist: String,
        albumName: String?
    ) async -> MotionArtworkSourceResolution? {
        let searchTitle = normalizedMusicDisplayTitle(title, artist: artist)
        let searchArtist = normalizedMusicDisplayArtist(artist, title: title)
        let localAlbumArtistCacheKey = normalizedMotionArtworkAlbumCacheKey(
            albumName: albumName,
            artistName: searchArtist
        )
        let localAlbumOnlyCacheKey = normalizedMotionArtworkAlbumCacheKey(
            albumName: albumName,
            artistName: nil as String?
        )
        let localAlbumCacheKeys = [localAlbumArtistCacheKey, localAlbumOnlyCacheKey].compactMap { $0 }

        if let cachedURL = mediaCacheStore.cachedMotionArtworkSourceURL(
            for: mediaID,
            maxAge: CachePolicy.motionArtworkSourceTTL
        ) {
            logAnimatedArtwork("Motion artwork source cache hit (media) for id=\(mediaID)")
            return MotionArtworkSourceResolution(
                sourceHLSURL: cachedURL,
                videoCacheID: motionArtworkVideoCacheID(
                    mediaID: mediaID,
                    albumCacheKey: localAlbumArtistCacheKey ?? localAlbumOnlyCacheKey,
                    sourceURL: cachedURL
                )
            )
        }

        if let albumHit = mediaCacheStore.cachedMotionArtworkSourceURL(
            forAlbumKeys: localAlbumCacheKeys,
            maxAge: CachePolicy.motionArtworkSourceTTL
        ) {
            logAnimatedArtwork("Motion artwork source cache hit (album key=\(albumHit.albumKey)) for id=\(mediaID)")
            mediaCacheStore.saveMotionArtworkSourceURL(albumHit.url, for: mediaID)
            return MotionArtworkSourceResolution(
                sourceHLSURL: albumHit.url,
                videoCacheID: motionArtworkVideoCacheID(
                    mediaID: mediaID,
                    albumCacheKey: albumHit.albumKey,
                    sourceURL: albumHit.url
                )
            )
        }

        #if canImport(iTunesKit)
        guard let resolution = await Self.resolveMotionArtwork(
            using: self.itunes,
            title: searchTitle,
            artist: searchArtist
        ) else {
            return nil
        }
        #else
        return nil
        #endif

        mediaCacheStore.saveMotionArtworkSourceURL(resolution.sourceURL, for: mediaID)

        var albumKeysToPersist = localAlbumCacheKeys
        let collectionCacheKey = motionArtworkCollectionCacheKey(collectionID: resolution.collectionID)
        if let collectionCacheKey {
            albumKeysToPersist.append(collectionCacheKey)
        }
        let catalogAlbumCacheKey = motionArtworkCatalogAlbumCacheKey(catalogAlbumID: resolution.catalogAlbumID)
        if let catalogAlbumCacheKey {
            albumKeysToPersist.append(catalogAlbumCacheKey)
        }
        mediaCacheStore.saveMotionArtworkSourceURL(resolution.sourceURL, forAlbumKeys: albumKeysToPersist)

        let selectedAlbumKey = catalogAlbumCacheKey
            ?? collectionCacheKey
            ?? localAlbumArtistCacheKey
            ?? localAlbumOnlyCacheKey
        logAnimatedArtwork(
            "Motion artwork source fetched from iTunes for id=\(mediaID) collection=\(resolution.collectionID.map(String.init) ?? "none")"
        )
        return MotionArtworkSourceResolution(
            sourceHLSURL: resolution.sourceURL,
            videoCacheID: motionArtworkVideoCacheID(
                mediaID: mediaID,
                albumCacheKey: selectedAlbumKey,
                sourceURL: resolution.sourceURL
            )
        )
    }

    #if canImport(iTunesKit)
    nonisolated private static func resolveMotionArtwork(
        using itunes: iTunesKit,
        title: String,
        artist: String
    ) async -> iTunesMotionArtworkResolution? {
        do {
            return try await itunes.resolveMotionArtwork(
                term: "\(title) \(artist)",
                country: "us"
            )
        } catch {
            return nil
        }
    }
    #endif

    nonisolated private static func fetchArtworkResource(from url: URL?) async -> CachedNowPlayingArtworkResource? {
        guard let url else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else { return nil }
            return CachedNowPlayingArtworkResource(url: url, data: data, size: image.size)
        } catch {
            return nil
        }
    }

    nonisolated private static func makeMediaItemArtwork(from resource: CachedNowPlayingArtworkResource) -> MPMediaItemArtwork? {
        let imageData = resource.data
        let boundsSize = resource.size

        return MPMediaItemArtwork(boundsSize: boundsSize) { _ in
            UIImage(data: imageData) ?? UIImage()
        }
    }

    @available(iOS 26.0, *)
    nonisolated private static func makeAnimatedArtwork(
        mediaID: String,
        videoURL: URL,
        previewData: Data?
    ) -> MPMediaItemAnimatedArtwork? {
        guard videoURL.isFileURL else {
            return nil
        }

        let artworkID = "\(mediaID)-\(videoURL.lastPathComponent)"
        return MPMediaItemAnimatedArtwork(
            artworkID: artworkID,
            previewImageRequestHandler: { requestedSize in
                guard let previewData,
                      let image = UIImage(data: previewData) else {
                    return nil
                }

                return makeAnimatedArtworkPreviewImage(
                    from: image,
                    requestedSize: requestedSize
                )
            },
            videoAssetFileURLRequestHandler: { _ in
                videoURL
            }
        )
    }

    @available(iOS 26.0, *)
    nonisolated private static func makeAnimatedArtworkPreviewImage(
        from image: UIImage,
        requestedSize: CGSize
    ) -> UIImage {
        let targetSize = normalizedAnimatedArtworkPreviewSize(
            requestedSize,
            fallbackSize: image.size
        )

        guard targetSize.width > 0,
              targetSize.height > 0,
              image.size.width > 0,
              image.size.height > 0 else {
            return image
        }

        let sourceAspectRatio = image.size.width / image.size.height
        let targetAspectRatio = targetSize.width / targetSize.height

        let drawRect: CGRect
        if sourceAspectRatio > targetAspectRatio {
            let scaledHeight = targetSize.height
            let scaledWidth = scaledHeight * sourceAspectRatio
            drawRect = CGRect(
                x: (targetSize.width - scaledWidth) / 2,
                y: 0,
                width: scaledWidth,
                height: scaledHeight
            )
        } else {
            let scaledWidth = targetSize.width
            let scaledHeight = scaledWidth / sourceAspectRatio
            drawRect = CGRect(
                x: 0,
                y: (targetSize.height - scaledHeight) / 2,
                width: scaledWidth,
                height: scaledHeight
            )
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale > 0 ? image.scale : 1

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            image.draw(in: drawRect)
        }
    }

    @available(iOS 26.0, *)
    nonisolated private static func normalizedAnimatedArtworkPreviewSize(
        _ requestedSize: CGSize,
        fallbackSize: CGSize
    ) -> CGSize {
        if requestedSize.width > 0,
           requestedSize.height > 0,
           requestedSize.width.isFinite,
           requestedSize.height.isFinite {
            return requestedSize
        }

        if fallbackSize.width > 0,
           fallbackSize.height > 0,
           fallbackSize.width.isFinite,
           fallbackSize.height.isFinite {
            return fallbackSize
        }

        return CGSize(width: 512, height: 512)
    }
#else
    func updateNowPlayingMetadata(force: Bool = true) {}
    func updateNowPlayingPlaybackInfo(force: Bool = false) {}
    func loadNowPlayingArtwork(for mediaID: String, title: String, artist: String, fallbackURL: URL?) {}
    func resolveMotionArtworkSource(
        for mediaID: String,
        title: String,
        artist: String,
        albumName: String?
    ) async -> MotionArtworkSourceResolution? {
        _ = mediaID
        _ = title
        _ = artist
        _ = albumName
        return nil
    }
#endif
}
