import Foundation
import Services
import Models

public final class LibraryDomain {
    internal let playlistLibraryStore: PlaylistLibraryStore
    internal let playlistImportJobStore: PlaylistImportJobStore
    internal let centralMediaStore: CentralMediaStore
    internal let mediaCacheStore: MediaCacheStore
    internal let metadataCache: any VideoMetadataCaching

    public init(
        playlistLibraryStore: PlaylistLibraryStore,
        playlistImportJobStore: PlaylistImportJobStore,
        centralMediaStore: CentralMediaStore,
        mediaCacheStore: MediaCacheStore,
        metadataCache: any VideoMetadataCaching
    ) {
        self.playlistLibraryStore = playlistLibraryStore
        self.playlistImportJobStore = playlistImportJobStore
        self.centralMediaStore = centralMediaStore
        self.mediaCacheStore = mediaCacheStore
        self.metadataCache = metadataCache
    }

    public var interface: LibraryInterface {
        LibraryInterface(
            playlistLibraryStore: playlistLibraryStore,
            playlistImportJobStore: playlistImportJobStore,
            centralMediaStore: centralMediaStore,
            mediaCacheStore: mediaCacheStore,
            metadataCache: metadataCache
        )
    }
}
