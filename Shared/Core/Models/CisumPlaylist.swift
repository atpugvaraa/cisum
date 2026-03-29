import Foundation
import SwiftData

enum PlaylistSourceProvider: String, Codable, CaseIterable, Sendable {
    case youtube
    case youtubeMusic = "youtube_music"
    case appleMusic = "apple_music"
    case spotify
    case unknown
}

@Model
final class Playlist {
    @Attribute(.unique) var playlistID: String

    var title: String
    var subtitle: String?
    var descriptionText: String?
    var artworkURLString: String?

    var sourceProviderRawValue: String
    var sourcePlaylistID: String?
    var sourceURLString: String?
    var sourceOwnerName: String?
    var sourceChecksum: String?

    var itemCount: Int
    var importedAt: Date
    var updatedAt: Date
    var lastPlayedAt: Date?

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
        self.sourceProviderRawValue = sourceProvider.rawValue
        self.sourcePlaylistID = sourcePlaylistID
        self.sourceURLString = sourceURLString
        self.sourceOwnerName = sourceOwnerName
        self.sourceChecksum = sourceChecksum
        self.itemCount = itemCount
        self.importedAt = importedAt
        self.updatedAt = updatedAt
        self.lastPlayedAt = lastPlayedAt
    }

    var sourceProvider: PlaylistSourceProvider {
        get { PlaylistSourceProvider(rawValue: sourceProviderRawValue) ?? .unknown }
        set { sourceProviderRawValue = newValue.rawValue }
    }
}