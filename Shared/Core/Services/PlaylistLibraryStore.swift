import Foundation
import SwiftData

@MainActor
final class PlaylistLibraryStore {
    struct PlaylistSnapshot: Sendable {
        let playlistID: String
        let title: String
        let subtitle: String?
        let descriptionText: String?
        let artworkURLString: String?
        let sourceProvider: PlaylistSourceProvider
        let sourcePlaylistID: String?
        let sourceURLString: String?
        let sourceOwnerName: String?
        let sourceChecksum: String?
        let itemCount: Int
        let importedAt: Date
        let updatedAt: Date
        let lastPlayedAt: Date?

        init(
            playlistID: String = UUID().uuidString,
            title: String,
            subtitle: String? = nil,
            descriptionText: String? = nil,
            artworkURLString: String? = nil,
            sourceProvider: PlaylistSourceProvider,
            sourcePlaylistID: String? = nil,
            sourceURLString: String? = nil,
            sourceOwnerName: String? = nil,
            sourceChecksum: String? = nil,
            itemCount: Int = 0,
            importedAt: Date = .now,
            updatedAt: Date = .now,
            lastPlayedAt: Date? = nil
        ) {
            self.playlistID = playlistID
            self.title = title
            self.subtitle = subtitle
            self.descriptionText = descriptionText
            self.artworkURLString = artworkURLString
            self.sourceProvider = sourceProvider
            self.sourcePlaylistID = sourcePlaylistID
            self.sourceURLString = sourceURLString
            self.sourceOwnerName = sourceOwnerName
            self.sourceChecksum = sourceChecksum
            self.itemCount = itemCount
            self.importedAt = importedAt
            self.updatedAt = updatedAt
            self.lastPlayedAt = lastPlayedAt
        }
    }

    struct PlaylistItemSnapshot: Sendable {
        let sortIndex: Int
        let sourceTrackID: String?
        let sourceTrackFingerprint: String
        let title: String
        let artistName: String?
        let albumName: String?
        let durationSeconds: Double?
        let artworkURLString: String?
        let resolvedMediaID: String?
        let resolutionConfidence: Double?
        let importStatus: PlaylistItemImportStatus
        let importErrorCode: String?
        let importErrorMessage: String?

        init(
            sortIndex: Int,
            sourceTrackID: String? = nil,
            sourceTrackFingerprint: String,
            title: String,
            artistName: String? = nil,
            albumName: String? = nil,
            durationSeconds: Double? = nil,
            artworkURLString: String? = nil,
            resolvedMediaID: String? = nil,
            resolutionConfidence: Double? = nil,
            importStatus: PlaylistItemImportStatus = .pending,
            importErrorCode: String? = nil,
            importErrorMessage: String? = nil
        ) {
            self.sortIndex = sortIndex
            self.sourceTrackID = sourceTrackID
            self.sourceTrackFingerprint = sourceTrackFingerprint
            self.title = title
            self.artistName = artistName
            self.albumName = albumName
            self.durationSeconds = durationSeconds
            self.artworkURLString = artworkURLString
            self.resolvedMediaID = resolvedMediaID
            self.resolutionConfidence = resolutionConfidence
            self.importStatus = importStatus
            self.importErrorCode = importErrorCode
            self.importErrorMessage = importErrorMessage
        }
    }

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func playlists(limit: Int? = nil) -> [Playlist] {
        var descriptor = FetchDescriptor<Playlist>(
            sortBy: [SortDescriptor(\Playlist.updatedAt, order: .reverse)]
        )

        if let limit, limit > 0 {
            descriptor.fetchLimit = limit
        }

        return (try? context.fetch(descriptor)) ?? []
    }

    func playlist(playlistID: String) -> Playlist? {
        var descriptor = FetchDescriptor<Playlist>(
            predicate: #Predicate { $0.playlistID == playlistID }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    func playlist(sourceProvider: PlaylistSourceProvider, sourcePlaylistID: String) -> Playlist? {
        let providerRawValue = sourceProvider.rawValue
        var descriptor = FetchDescriptor<Playlist>(
            predicate: #Predicate {
                $0.sourceProviderRawValue == providerRawValue && $0.sourcePlaylistID == sourcePlaylistID
            }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    func items(for playlistID: String) -> [PlaylistItem] {
        let descriptor = FetchDescriptor<PlaylistItem>(
            predicate: #Predicate { $0.playlistID == playlistID },
            sortBy: [SortDescriptor(\PlaylistItem.sortIndex, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    @discardableResult
    func upsertPlaylist(_ snapshot: PlaylistSnapshot) -> Playlist {
        let entry = playlist(playlistID: snapshot.playlistID) ?? {
            let created = Playlist(
                playlistID: snapshot.playlistID,
                title: snapshot.title,
                subtitle: snapshot.subtitle,
                descriptionText: snapshot.descriptionText,
                artworkURLString: snapshot.artworkURLString,
                sourceProvider: snapshot.sourceProvider,
                sourcePlaylistID: snapshot.sourcePlaylistID,
                sourceURLString: snapshot.sourceURLString,
                sourceOwnerName: snapshot.sourceOwnerName,
                sourceChecksum: snapshot.sourceChecksum,
                itemCount: snapshot.itemCount,
                importedAt: snapshot.importedAt,
                updatedAt: snapshot.updatedAt,
                lastPlayedAt: snapshot.lastPlayedAt
            )
            context.insert(created)
            return created
        }()

        entry.title = snapshot.title
        entry.subtitle = snapshot.subtitle
        entry.descriptionText = snapshot.descriptionText
        entry.artworkURLString = snapshot.artworkURLString
        entry.sourceProvider = snapshot.sourceProvider
        entry.sourcePlaylistID = snapshot.sourcePlaylistID
        entry.sourceURLString = snapshot.sourceURLString
        entry.sourceOwnerName = snapshot.sourceOwnerName
        entry.sourceChecksum = snapshot.sourceChecksum
        entry.itemCount = snapshot.itemCount
        entry.importedAt = snapshot.importedAt
        entry.updatedAt = snapshot.updatedAt
        entry.lastPlayedAt = snapshot.lastPlayedAt
        saveContext()
        return entry
    }

    func replaceItems(for playlistID: String, with snapshots: [PlaylistItemSnapshot]) {
        let existingItems = items(for: playlistID)
        for item in existingItems {
            context.delete(item)
        }

        for snapshot in snapshots.sorted(by: { $0.sortIndex < $1.sortIndex }) {
            let created = PlaylistItem(
                playlistID: playlistID,
                sortIndex: snapshot.sortIndex,
                sourceTrackID: snapshot.sourceTrackID,
                sourceTrackFingerprint: snapshot.sourceTrackFingerprint,
                title: snapshot.title,
                artistName: snapshot.artistName,
                albumName: snapshot.albumName,
                durationSeconds: snapshot.durationSeconds,
                artworkURLString: snapshot.artworkURLString,
                resolvedMediaID: snapshot.resolvedMediaID,
                resolutionConfidence: snapshot.resolutionConfidence,
                importStatus: snapshot.importStatus,
                importErrorCode: snapshot.importErrorCode,
                importErrorMessage: snapshot.importErrorMessage,
                createdAt: .now,
                updatedAt: .now
            )
            context.insert(created)
        }

        if let playlist = playlist(playlistID: playlistID) {
            playlist.itemCount = snapshots.count
            playlist.updatedAt = .now
        }

        saveContext()
    }

    func deletePlaylist(playlistID: String) {
        for item in items(for: playlistID) {
            context.delete(item)
        }

        if let playlist = playlist(playlistID: playlistID) {
            context.delete(playlist)
        }

        saveContext()
    }

    func markPlaylistPlayed(playlistID: String, playedAt: Date = .now) {
        guard let playlist = playlist(playlistID: playlistID) else {
            return
        }

        playlist.lastPlayedAt = playedAt
        playlist.updatedAt = .now
        saveContext()
    }

    private func saveContext() {
        try? context.save()
    }
}