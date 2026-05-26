import Services
import SwiftUI
import YouTubeSDK

public struct PluginsView: View {
    public init() {}

    @Environment(ServicesContainer.self) private var container
    @Environment(StreamingProviderSettings.self) private var streamingProviderSettings

    @AppStorage("plugins.provider_sdk_enabled") private var providerSDKEnabled = true
    @AppStorage("plugins.youtube_fallback_enabled") private var youtubeFallbackEnabled = true

    public var body: some View {
        Form {
            Section("Playback Chain") {
                Toggle("Enable ProviderSDK", isOn: $providerSDKEnabled)
                Toggle("Enable YouTube Fallback", isOn: $youtubeFallbackEnabled)

                LabeledContent("Active Providers", value: activeProvidersLabel)

                Text(
                    "ProviderSDK resolves first when enabled. YouTube fallback stays available so playback never ends up with an empty resolver chain."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)

                Button("Apply Now") {
                    applyPlaybackConfiguration()
                }
            }

            Section("Streaming Sources") {
                Picker(
                    "Radio Recommendations",
                    selection: Bindable(streamingProviderSettings).recommendationSource
                ) {
                    ForEach(StreamingProviderSettings.RecommendationSource.allCases) { source in
                        Text(source.rawValue).tag(source)
                    }
                }

                Toggle(
                    "Prefer Anonymous Spotify Fallback",
                    isOn: Bindable(streamingProviderSettings).spotifyPreferAnonymousFallback
                )

                LabeledContent("Spotify Mode", value: streamingProviderSettings.spotifyModeLabel)
                LabeledContent(
                    "Spotify Credentials",
                    value: streamingProviderSettings.hasSpotifyCredentials ? "Configured" : "Missing"
                )
            }

            Section("Status") {
                LabeledContent("ProviderSDK", value: providerSDKEnabled ? "Enabled" : "Disabled")
                LabeledContent("YouTube Fallback", value: youtubeFallbackEnabled ? "Enabled" : "Disabled")
            }
        }
        .navigationTitle("Plugins")
        .onAppear {
            applyPlaybackConfiguration()
        }
        .onChange(of: providerSDKEnabled) { _, _ in
            applyPlaybackConfiguration()
        }
        .onChange(of: youtubeFallbackEnabled) { _, _ in
            applyPlaybackConfiguration()
        }
    }

    private var activeProvidersLabel: String {
        var providers: [String] = []

        if providerSDKEnabled {
            providers.append("ProviderSDK")
        }

        if youtubeFallbackEnabled || providers.isEmpty {
            providers.append("YouTube")
        }

        return providers.joined(separator: " -> ")
    }

    private func applyPlaybackConfiguration() {
        Plugins.configurePlaybackURLResolver(
            youtube: container.app.youtube,
            mediaCacheStore: container.library.mediaCacheStore,
            metadataCache: container.library.metadataCache,
            includeProviderSDK: providerSDKEnabled,
            includeYouTubeFallback: youtubeFallbackEnabled
        )
    }
}