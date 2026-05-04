import Foundation
import SwiftData
import Models

@MainActor
public final class PlaylistLibraryStore {
    public struct PlaylistSnapshot: Sendable {
        public let playlistID: String
        public let title: String
        public let subtitle: String?
        public let descriptionText: String?
        public let artworkURLString: String?
        public let sourceProvider: PlaylistSource
        public let sourcePlaylistID: String?
        public let sourceURLString: String?
        public let sourceOwnerName: String?
        public let sourceChecksum: String?
        public let itemCount: Int
        public let importedAt: Date
        public let updatedAt: Date
        public let lastPlayedAt: Date?

        public init(
            playlistID: String = UUID().uuidString,
            title: String,
            subtitle: String? = nil,
            descriptionText: String? = nil,
            artworkURLString: String? = nil,
            sourceProvider: PlaylistSource,
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

    public struct PlaylistItemSnapshot: Sendable {
        public let sortIndex: Int
        public let sourceTrackID: String?
        public let sourceTrackFingerprint: String
        public let title: String
        public let artistName: String?
        public let albumName: String?
        public let durationSeconds: Double?
        public let artworkURLString: String?
        public let resolvedMediaID: String?
        public let resolutionConfidence: Double?
        public let importStatus: PlaylistItemImportStatus
        public let importErrorCode: String?
        public let importErrorMessage: String?

        public init(
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

    public init(context: ModelContext) {
        self.context = context
    }

    public func playlists(limit: Int? = nil) -> [Playlist] {
        var descriptor = FetchDescriptor<Playlist>(
            sortBy: [SortDescriptor(\Playlist.updatedAt, order: .reverse)]
        )

        if let limit, limit > 0 {
            descriptor.fetchLimit = limit
        }

        return (try? context.fetch(descriptor)) ?? []
    }

    public func playlist(playlistID: String) -> Playlist? {
        var descriptor = FetchDescriptor<Playlist>(
            predicate: #Predicate { $0.playlistID == playlistID }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    public func playlist(sourceProvider: PlaylistSource, sourcePlaylistID: String) -> Playlist? {
        let providerRawValue = sourceProvider.rawValue
        var descriptor = FetchDescriptor<Playlist>(
            predicate: #Predicate {
                $0.sourceProviderRawValue == providerRawValue && $0.sourcePlaylistID == sourcePlaylistID
            },
            sortBy: [SortDescriptor(\Playlist.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    public func items(for playlistID: String) -> [PlaylistItem] {
        let descriptor = FetchDescriptor<PlaylistItem>(
            predicate: #Predicate { $0.playlistID == playlistID },
            sortBy: [SortDescriptor(\PlaylistItem.sortIndex, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    @discardableResult
    public func upsertPlaylist(_ snapshot: PlaylistSnapshot) -> Playlist {
        let entry = playlist(playlistID: snapshot.playlistID) ?? {
            let created = Playlist(
                playlistID: snapshot.playlistID,
                title: snapshot.title,
                normalizedTitle: snapshot.title.lowercased(),
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

    public func replaceItems(for playlistID: String, with snapshots: [PlaylistItemSnapshot]) {
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

    public func deletePlaylist(playlistID: String) {
        for item in items(for: playlistID) {
            context.delete(item)
        }

        if let playlist = playlist(playlistID: playlistID) {
            context.delete(playlist)
        }

        saveContext()
    }

    public func markPlaylistPlayed(playlistID: String, playedAt: Date = .now) {
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