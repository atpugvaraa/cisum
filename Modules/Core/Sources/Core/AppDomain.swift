import Foundation
import YouTubeSDK
import DesignSystem
import Services
import SwiftData
import Utilities

public final class AppDomain {
    internal let youtube: YouTube
    internal let router: Router
    internal let modelContainer: ModelContainer
    internal let playerPresentationController: PlayerPresentationController
    internal let searchOverlayController: SearchOverlayController

    public init(
        youtube: YouTube,
        router: Router,
        modelContainer: ModelContainer,
        playerPresentationController: PlayerPresentationController,
        searchOverlayController: SearchOverlayController
    ) {
        self.youtube = youtube
        self.router = router
        self.modelContainer = modelContainer
        self.playerPresentationController = playerPresentationController
        self.searchOverlayController = searchOverlayController
    }

    public var interface: AppInterface {
        AppInterface(
            youtube: youtube,
            router: router,
            modelContainer: modelContainer,
            playerPresentationController: playerPresentationController,
            searchOverlayController: searchOverlayController
        )
    }
}
