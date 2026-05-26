#if os(iOS)
import SwiftUI
import SwiftData
import Models

public struct AlbumDetailWrapper: View {
    public let albumID: String

    @Query private var albums: [Album]

    public init(albumID: String) {
        self.albumID = albumID
        _albums = Query(filter: #Predicate<Album> { $0.albumID == albumID })
    }

    public var body: some View {
        if let album = albums.first {
            AlbumView(album: album)
        } else {
            ProgressView()
        }
    }
}
#endif
