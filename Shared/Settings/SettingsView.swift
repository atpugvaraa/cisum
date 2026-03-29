import SwiftUI

struct SettingsView: View {
    @Environment(PrefetchSettings.self) private var settings
    @Environment(NetworkPathMonitor.self) private var networkMonitor
    @State private var playbackControlSettings = PlaybackControlSettings.shared

    @State private var snapshot = PlaybackMetricsStore.Snapshot(
        cacheHitRate: 0,
        avgResolveMs: 0,
        avgTapToPlayMs: 0,
        resolveSampleCount: 0,
        tapToPlaySampleCount: 0
    )

    #if DEBUG
    @ObserveInjection var forceRedraw
    #endif

    var body: some View {
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
                
                Toggle("Suggestion Preload Pipeline", isOn: Bindable(settings).suggestionPipelineEnabled)
            }
            
            Section("Network") {
                LabeledContent("Profile", value: networkMonitor.profileName)
                LabeledContent("Interface", value: networkMonitor.interface.rawValue)
                LabeledContent("Expensive", value: networkMonitor.isExpensive ? "Yes" : "No")
                LabeledContent("Constrained", value: networkMonitor.isConstrained ? "Yes" : "No")
            }

#if os(iOS)
            Section("Playback Controls") {
                Toggle("Hold Volume Buttons To Skip", isOn: Bindable(playbackControlSettings).volumeButtonHoldSkipEnabled)

                Text("Single taps still change system volume. Skip starts only after the activation delay while playback is active.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text("At exact 0% or 100% while playing, cisum keeps a tiny headroom reserve so hold-to-skip can still latch reliably.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                LabeledContent("Activation Delay", value: "\(Int(playbackControlSettings.volumeButtonHoldThreshold * 1000)) ms")
                Slider(
                    value: Bindable(playbackControlSettings).volumeButtonHoldThreshold,
                    in: 0.6...1.2,
                    step: 0.05
                )

                LabeledContent("Repeat Interval", value: "\(Int(playbackControlSettings.volumeButtonHoldRepeatInterval * 1000)) ms")
                Slider(
                    value: Bindable(playbackControlSettings).volumeButtonHoldRepeatInterval,
                    in: 0.35...0.8,
                    step: 0.05
                )

                LabeledContent("Release Timeout", value: "\(Int(playbackControlSettings.volumeButtonHoldReleaseTimeout * 1000)) ms")
                Slider(
                    value: Bindable(playbackControlSettings).volumeButtonHoldReleaseTimeout,
                    in: 0.12...0.35,
                    step: 0.01
                )

                Toggle("Lock Volume During Hold", isOn: Bindable(playbackControlSettings).volumeButtonHoldRestoreVolume)
                Toggle("Volume Up Skips Forward", isOn: Bindable(playbackControlSettings).volumeButtonHoldUpSkipsForward)
            }
#endif
            
            Section("Diagnostics") {
                Toggle("Enable Metrics", isOn: Bindable(settings).metricsEnabled)
                LabeledContent("Cache Hit %", value: String(format: "%.1f%%", snapshot.cacheHitRate * 100))
                LabeledContent("Avg Resolve", value: String(format: "%.0f ms", snapshot.avgResolveMs))
                LabeledContent("Avg Tap-to-Play", value: String(format: "%.0f ms", snapshot.avgTapToPlayMs))
                LabeledContent("Resolve Samples", value: "\(snapshot.resolveSampleCount)")
                LabeledContent("Tap-to-Play Samples", value: "\(snapshot.tapToPlaySampleCount)")
                
                Button("Refresh Metrics") {
                    Task { await refreshMetrics() }
                }
                Button("Reset Metrics", role: .destructive) {
                    Task {
                        await PlaybackMetricsStore.shared.reset()
                        await refreshMetrics()
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .task {
            await refreshMetrics()
        }
        .enableInjection()
    }

    private func refreshMetrics() async {
        snapshot = await PlaybackMetricsStore.shared.snapshot()
    }
}

#Preview {
    SettingsView()
        .environment(PrefetchSettings.shared)
        .environment(NetworkPathMonitor.shared)
}
