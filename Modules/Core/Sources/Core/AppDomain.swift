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

    public init(
        youtube: YouTube,
        router: Router,
        modelContainer: ModelContainer
    ) {
        self.youtube = youtube
        self.router = router
        self.modelContainer = modelContainer
    }

    public var interface: AppInterface {
        AppInterface(
            youtube: youtube,
            router: router,
            modelContainer: modelContainer
        )
    }
}
