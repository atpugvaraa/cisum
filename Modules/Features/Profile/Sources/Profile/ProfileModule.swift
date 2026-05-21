import Services
import SwiftUI
import YouTubeSDK

public final class ProfileModule {
    private let prefetchSettings: PrefetchSettings
    private let networkMonitor: NetworkPathMonitor
    private let playbackControlSettings: PlaybackControlSettings
    private let streamingProviderSettings: StreamingProviderSettings
    private let lastFMSettings: LastFMSettings

    public init(
        prefetchSettings: PrefetchSettings,
        networkMonitor: NetworkPathMonitor,
        playbackControlSettings: PlaybackControlSettings,
        streamingProviderSettings: StreamingProviderSettings
        , lastFMSettings: LastFMSettings
    ) {
        self.prefetchSettings = prefetchSettings
        self.networkMonitor = networkMonitor
        self.playbackControlSettings = playbackControlSettings
        self.streamingProviderSettings = streamingProviderSettings
        self.lastFMSettings = lastFMSettings
    }

    public var profileView: some View {
        ProfileView()
            .environment(prefetchSettings)
            .environment(networkMonitor)
            .environment(playbackControlSettings)
            .environment(streamingProviderSettings)
    }

    public var settingsView: some View {
        SettingsView()
            .environment(prefetchSettings)
            .environment(networkMonitor)
            .environment(playbackControlSettings)
            .environment(streamingProviderSettings)
            .environment(lastFMSettings)
    }
}
