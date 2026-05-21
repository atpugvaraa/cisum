import Models
import Services
import SwiftUI

public struct SettingsView: View {
    public init() {}

    @Environment(PrefetchSettings.self) private var settings
    @Environment(NetworkPathMonitor.self) private var networkMonitor
    @Environment(PlaybackControlSettings.self) private var playbackControlSettings
    @Environment(StreamingProviderSettings.self) private var streamingProviderSettings
    @Environment(PlaybackServices.self) private var playbackServices
    @Environment(UserServices.self) private var userServices
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    private var lastFMSettings: LastFMSettings { playbackServices.lastFMSettings }
    private var lastFMScrobbler: LastFMScrobbler { playbackServices.lastFMScrobbler }

    @State private var snapshot = PlaybackMetricsStore.Snapshot(
        cacheHitRate: 0,
        avgResolveMs: 0,
        avgTapToPlayMs: 0,
        resolveSampleCount: 0,
        tapToPlaySampleCount: 0
    )

    @State private var isSigningOut: Bool = false
    @State private var isConnectingLastFM: Bool = false
    @State private var pendingFlowId: String?

    public var body: some View {
        Form {
            Section("Prefetch") {
                Toggle("Adaptive Prefetch", isOn: Bindable(settings).adaptivePrefetchEnabled)

                Picker("Mode", selection: Bindable(settings).prefetchModeOverride) {
                    ForEach(PrefetchModeOverride.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }

                HStack {
                    Text("Wi-Fi Prefetch Count")
                    Spacer()
                    Text("\(settings.wifiPrefetchCount)")
                        .foregroundStyle(.secondary)
                }
                Slider(
                    value: Binding(
                        get: { Double(settings.wifiPrefetchCount) },
                        set: { settings.wifiPrefetchCount = Int($0.rounded()) }
                    ),
                    in: 1...10,
                    step: 1
                )

                HStack {
                    Text("Cellular Prefetch Count")
                    Spacer()
                    Text("\(settings.cellularPrefetchCount)")
                        .foregroundStyle(.secondary)
                }
                Slider(
                    value: Binding(
                        get: { Double(settings.cellularPrefetchCount) },
                        set: { settings.cellularPrefetchCount = Int($0.rounded()) }
                    ),
                    in: 1...5,
                    step: 1
                )

                Toggle(
                    "Suggestion Preload Pipeline",
                    isOn: Bindable(settings).suggestionPipelineEnabled)
            }

            Section("Network") {

                LabeledContent("Profile", value: networkMonitor.profileName)
                LabeledContent("Interface", value: networkMonitor.interface.rawValue)
                LabeledContent("Expensive", value: networkMonitor.isExpensive ? "Yes" : "No")
                LabeledContent("Constrained", value: networkMonitor.isConstrained ? "Yes" : "No")
            }

            #if os(iOS)
                Section("Playback Controls") {
                    Toggle(
                        "Hold Volume Buttons To Skip",
                        isOn: Bindable(playbackControlSettings).volumeButtonHoldSkipEnabled)

                    Text(
                        "Single taps still change system volume. Skip starts only after the activation delay while playback is active."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                    Text(
                        "At exact 0% or 100% while playing, cisum keeps a tiny headroom reserve so hold-to-skip can still latch reliably."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                    LabeledContent(
                        "Activation Delay",
                        value: "\(Int(playbackControlSettings.volumeButtonHoldThreshold * 1000)) ms"
                    )
                    Slider(
                        value: Bindable(playbackControlSettings).volumeButtonHoldThreshold,
                        in: 0.6...1.2,
                        step: 0.05
                    )

                    LabeledContent(
                        "Repeat Interval",
                        value:
                            "\(Int(playbackControlSettings.volumeButtonHoldRepeatInterval * 1000)) ms"
                    )
                    Slider(
                        value: Bindable(playbackControlSettings).volumeButtonHoldRepeatInterval,
                        in: 0.35...0.8,
                        step: 0.05
                    )

                    LabeledContent(
                        "Release Timeout",
                        value:
                            "\(Int(playbackControlSettings.volumeButtonHoldReleaseTimeout * 1000)) ms"
                    )
                    Slider(
                        value: Bindable(playbackControlSettings).volumeButtonHoldReleaseTimeout,
                        in: 0.12...0.35,
                        step: 0.01
                    )

                    Toggle(
                        "Lock Volume During Hold",
                        isOn: Bindable(playbackControlSettings).volumeButtonHoldRestoreVolume)
                    Toggle(
                        "Volume Up Skips Forward",
                        isOn: Bindable(playbackControlSettings).volumeButtonHoldUpSkipsForward)
                }
            #endif

            Section("Diagnostics") {
                Toggle("Enable Metrics", isOn: Bindable(settings).metricsEnabled)
                LabeledContent(
                    "Cache Hit %", value: String(format: "%.1f%%", snapshot.cacheHitRate * 100))
                LabeledContent(
                    "Avg Resolve", value: String(format: "%.0f ms", snapshot.avgResolveMs))
                LabeledContent(
                    "Avg Tap-to-Play", value: String(format: "%.0f ms", snapshot.avgTapToPlayMs))
                LabeledContent("Resolve Samples", value: "\(snapshot.resolveSampleCount)")
                LabeledContent("Tap-to-Play Samples", value: "\(snapshot.tapToPlaySampleCount)")

                Button("Refresh Metrics") {
                    Task { await refreshMetrics() }
                }
                Button("Reset Metrics", role: .destructive) {
                    Task {
                        await playbackServices.playbackMetricsStore.reset()
                        await refreshMetrics()
                    }
                }
            }

            Section("Last.fm") {
                Toggle("Enable Scrobbling", isOn: Bindable(lastFMSettings).enabled)
                Toggle(
                    "Save Local Listening History",
                    isOn: Bindable(lastFMSettings).localHistoryEnabled
                )

                if lastFMSettings.isConnected {
                    LabeledContent {
                        Button("Disconnect", role: .destructive) {
                            Task {
                                do {
                                    try await lastFMScrobbler.disconnect()
                                    lastFMSettings.clearConnection()
                                } catch {
                                    // Handle error if needed
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Connected as \(lastFMSettings.lastfmUsername ?? "User")")
                        }
                    }
                } else {
                    if userServices.authService.isAuthenticated {
                        Button {
                            Task {
                                isConnectingLastFM = true
                                defer { isConnectingLastFM = false }
                                do {
                                    let flow = try await lastFMScrobbler.startConnection()
                                    pendingFlowId = flow.flowId
                                    if let url = URL(string: flow.authorizeUrl) {
                                        openURL(url)
                                    }
                                } catch {
                                    // Handle error
                                }
                            }
                        } label: {
                            HStack {
                                Text("Connect Last.fm")
                                if isConnectingLastFM {
                                    Spacer()
                                    ProgressView().controlSize(.small)
                                }
                            }
                        }
                        .disabled(isConnectingLastFM)
                    } else {
                        Text("Sign in to cisum to connect Last.fm")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("Last.fm authorization will be connected through a secure web flow, not by entering your shared secret in the app.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .contentMargins(.bottom, 140)
        .task {
            await refreshMetrics()
            await refreshLastFMStatus()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                Task {
                    await refreshLastFMStatus()
                    
                    if let flowId = pendingFlowId {
                        do {
                            let result = try await lastFMScrobbler.completeConnection(flowId: flowId)
                            if result.connected {
                                lastFMSettings.updateConnectionStatus(connected: true, username: result.lastfmUsername)
                                pendingFlowId = nil
                            }
                        } catch {
                            // Flow may have expired or not been completed yet
                        }
                    }
                }
            }
        }
    }

    private func refreshLastFMStatus() async {
        do {
            let status = try await lastFMScrobbler.checkConnectionStatus()
            lastFMSettings.updateConnectionStatus(connected: status.connected, username: status.lastfmUsername)
        } catch {
            // Unauthenticated or network error
        }
    }

    private func refreshMetrics() async {
        snapshot = await playbackServices.playbackMetricsStore.snapshot()
    }
}

#if DEBUG
    #Preview {
        SettingsView()
    }
#endif
