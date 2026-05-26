#if os(iOS)
import SwiftUI
import SwiftData
import Models

public struct ArtistDetailWrapper: View {
    public let artistID: String

    @Query private var artists: [Artist]

    public init(artistID: String) {
        self.artistID = artistID
        _artists = Query(filter: #Predicate<Artist> { $0.artistID == artistID })
    }

    public var body: some View {
        if let artist = artists.first {
            ArtistView(artist: artist)
        } else {
            ProgressView()
        }
    }
}
#endif
