import Foundation
import SwiftData

@Model
public final class Playlist {
    @Attribute(.unique) public var playlistID: String

    public var title: String
    public var normalizedTitle: String
    public var subtitle: String?
    public var descriptionText: String?
    public var ownerName: String?
    public var artworkURLString: String?

    public var sourceProviderRawValue: String?
    public var sourcePlaylistID: String?
    public var sourceURLString: String?
    public var sourceOwnerName: String?
    public var sourceChecksum: String?

    public var itemCount: Int
    public var songIDs: Data?

    public var createdAt: Date = Date()
    public var importedAt: Date?
    public var updatedAt: Date = Date()
    public var lastPlayedAt: Date?

    public init(
        playlistID: String = UUID().uuidString,
        title: String,
        normalizedTitle: String,
        subtitle: String? = nil,
        descriptionText: String? = nil,
        ownerName: String? = nil,
        artworkURLString: String? = nil,
        sourceProvider: PlaylistSource? = nil,
        sourcePlaylistID: String? = nil,
        sourceURLString: String? = nil,
        sourceOwnerName: String? = nil,
        sourceChecksum: String? = nil,
        itemCount: Int = 0,
        songIDs: Data? = nil,
        createdAt: Date = .now,
        importedAt: Date? = .now,
        updatedAt: Date = .now,
        lastPlayedAt: Date? = nil
    ) {
        self.playlistID = playlistID
        self.title = title
        self.normalizedTitle = normalizedTitle
        self.subtitle = subtitle
        self.descriptionText = descriptionText
        self.ownerName = ownerName
        self.artworkURLString = artworkURLString
        self.sourceProviderRawValue = sourceProvider?.rawValue
        self.sourcePlaylistID = sourcePlaylistID
        self.sourceURLString = sourceURLString
        self.sourceOwnerName = sourceOwnerName
        self.sourceChecksum = sourceChecksum
        self.itemCount = itemCount
        self.songIDs = songIDs
        self.createdAt = createdAt
        self.importedAt = importedAt
        self.updatedAt = updatedAt
        self.lastPlayedAt = lastPlayedAt
    }

    public var sourceProvider: PlaylistSource? {
        get { sourceProviderRawValue.flatMap(PlaylistSource.init(rawValue:)) }
        set { sourceProviderRawValue = newValue?.rawValue }
    }
}

