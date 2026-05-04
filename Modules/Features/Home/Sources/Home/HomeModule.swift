import SwiftUI
import YouTubeSDK

public final class HomeModule {
    private let youtube: YouTube

    public init(youtube: YouTube) {
        self.youtube = youtube
    }

    public var view: some View {
        HomeView(youtube: youtube)
    }
}
