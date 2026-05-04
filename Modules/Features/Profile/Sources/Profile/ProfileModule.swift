import Services
import SwiftUI

public final class ProfileModule {
    private let prefetchSettings: PrefetchSettings
    private let networkMonitor: NetworkPathMonitor
    private let playbackControlSettings: PlaybackControlSettings
    private let streamingProviderSettings: StreamingProviderSettings

    public init(
        prefetchSettings: PrefetchSettings,
        networkMonitor: NetworkPathMonitor,
        playbackControlSettings: PlaybackControlSettings,
        streamingProviderSettings: StreamingProviderSettings
    ) {
        self.prefetchSettings = prefetchSettings
        self.networkMonitor = networkMonitor
        self.playbackControlSettings = playbackControlSettings
        self.streamingProviderSettings = streamingProviderSettings
    }

    public var settingsView: some View {
        SettingsView()
            .environment(prefetchSettings)
            .environment(networkMonitor)
            .environment(playbackControlSettings)
            .environment(streamingProviderSettings)
    }
}
