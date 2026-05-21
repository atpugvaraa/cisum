import SwiftUI

public final class LibraryModule {
    public init() {}

    public var view: some View {
        LibraryView()
    }

    public func playlistDetailView(for id: String) -> some View {
        PlaylistDetailView(playlistID: id)
    }
}
