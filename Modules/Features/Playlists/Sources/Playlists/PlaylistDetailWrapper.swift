import SwiftUI
import SwiftData
import Models

public struct PlaylistDetailWrapper: View {
    public let playlistID: String

    @Query private var playlists: [Playlist]

    public init(playlistID: String) {
        self.playlistID = playlistID
        _playlists = Query(filter: #Predicate<Playlist> { $0.playlistID == playlistID })
    }

    public var body: some View {
        if let playlist = playlists.first {
            PlaylistView(playlist: playlist)
        } else {
            ProgressView()
        }
    }
}
