import Observation
import Foundation

@Observable
@MainActor
public final class ServicesContainer {
    public let core: CoreInterface
    public let playback: PlaybackInterface
    public let search: SearchInterface
    public let library: LibraryInterface
    public let user: UserInterface
    public let app: AppInterface

    public init(
        core: CoreInterface,
        playback: PlaybackInterface,
        search: SearchInterface,
        library: LibraryInterface,
        user: UserInterface,
        app: AppInterface
    ) {
        self.core = core
        self.playback = playback
        self.search = search
        self.library = library
        self.user = user
        self.app = app
    }
}
