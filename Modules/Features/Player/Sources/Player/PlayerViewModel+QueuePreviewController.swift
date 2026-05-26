import Foundation
import Models
import YouTubeSDK
import Utilities

extension PlayerViewModel {

    public struct QueuePreviewItem: Identifiable, Equatable {
        public let id: String
        public let title: String
        public let subtitle: String
        public let artworkURL: URL?
        
        public init(id: String, title: String, subtitle: String, artworkURL: URL?) {
            self.id = id
            self.title = title
            self.subtitle = subtitle
            self.artworkURL = artworkURL
        }
    }

    var currentQueuePreviewIndex: Int? {
        queuePosition
    }

    var previousQueuePreviewItem: QueuePreviewItem? {
        guard let queuePosition,
              queuePosition > 0,
              queuePreviewItems.indices.contains(queuePosition - 1) else {
            return nil
        }

        return queuePreviewItems[queuePosition - 1]
    }

    var nextQueuePreviewItem: QueuePreviewItem? {
        guard let queuePosition,
              queuePreviewItems.indices.contains(queuePosition + 1) else {
            return nil
        }

        return queuePreviewItems[queuePosition + 1]
    }

    func updateQueuePreviewItems() {
        let entries = playbackQueue
        Task { [weak self] in
            guard let self = self else { return }
            let items = await self.mapQueueEntriesToPreview(entries)
            await MainActor.run {
                self.queuePreviewItems = items
            }
        }
    }

    nonisolated func mapQueueEntriesToPreview(_ entries: [PlaybackQueueEntry]) async -> [QueuePreviewItem] {
        return entries.map { entry in
            switch entry {
            case .song(let song):
                return QueuePreviewItem(
                    id: song.videoId,
                    title: normalizedMusicDisplayTitle(song.title, artist: song.artistsDisplay),
                    subtitle: normalizedMusicDisplayArtist(song.artistsDisplay, title: song.title),
                    artworkURL: song.thumbnailURL
                )
            case .video(let video):
                return QueuePreviewItem(
                    id: video.id,
                    title: normalizedMusicDisplayTitle(video.title, artist: video.author),
                    subtitle: normalizedMusicDisplayArtist(video.author, title: video.title),
                    artworkURL: normalizedArtworkURL(from: video.thumbnailURL)
                )
            case .cachedRadio(let track):
                return QueuePreviewItem(
                    id: track.videoID,
                    title: normalizedMusicDisplayTitle(track.title, artist: track.artist),
                    subtitle: normalizedMusicDisplayArtist(track.artist, title: track.title),
                    artworkURL: track.thumbnailURL
                )
            case .external(let track):
                return QueuePreviewItem(
                    id: track.mediaID,
                    title: normalizedMusicDisplayTitle(track.title, artist: track.artist),
                    subtitle: normalizedMusicDisplayArtist(track.artist, title: track.title),
                    artworkURL: track.artworkURL
                )
            }
        }
    }
}
