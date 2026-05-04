import Foundation
import Services

public final class UserDomain {
    internal let spotifySessionCoordinator: SpotifySessionCoordinator

    public init(spotifySessionCoordinator: SpotifySessionCoordinator) {
        self.spotifySessionCoordinator = spotifySessionCoordinator
    }

    public var interface: UserInterface {
        UserInterface(spotifySessionCoordinator: spotifySessionCoordinator)
    }
}
