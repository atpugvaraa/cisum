import SwiftUI

enum PrefetchModeOverride: String, CaseIterable, Identifiable {
    case auto
    case metadataOnly
    case aggressiveWarmup

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: return "Auto"
        case .metadataOnly: return "Metadata Only"
        case .aggressiveWarmup: return "Aggressive Warmup"
        }
    }
}

@Observable
@MainActor
final class PrefetchSettings {
    static let shared = PrefetchSettings()

    private enum Keys {
        static let adaptiveEnabled = "prefetch.adaptive.enabled"
        static let modeOverride = "prefetch.mode.override"
        static let wifiCount = "prefetch.wifi.count"
        static let cellularCount = "prefetch.cellular.count"
        static let wifiConcurrency = "prefetch.wifi.concurrency"
        static let cellularConcurrency = "prefetch.cellular.concurrency"
        static let metricsEnabled = "prefetch.metrics.enabled"
        static let suggestionPipelineEnabled = "prefetch.suggestions.pipeline.enabled"
    }

    private let defaults: UserDefaults

    var adaptivePrefetchEnabled: Bool {
        didSet { defaults.set(adaptivePrefetchEnabled, forKey: Keys.adaptiveEnabled) }
    }

    var prefetchModeOverride: PrefetchModeOverride {
        didSet { defaults.set(prefetchModeOverride.rawValue, forKey: Keys.modeOverride) }
    }

    var wifiPrefetchCount: Int {
        didSet { defaults.set(wifiPrefetchCount, forKey: Keys.wifiCount) }
    }

    var cellularPrefetchCount: Int {
        didSet { defaults.set(cellularPrefetchCount, forKey: Keys.cellularCount) }
    }

    var wifiPrefetchConcurrency: Int {
        didSet { defaults.set(wifiPrefetchConcurrency, forKey: Keys.wifiConcurrency) }
    }

    var cellularPrefetchConcurrency: Int {
        didSet { defaults.set(cellularPrefetchConcurrency, forKey: Keys.cellularConcurrency) }
    }

    var metricsEnabled: Bool {
        didSet { defaults.set(metricsEnabled, forKey: Keys.metricsEnabled) }
    }

    var suggestionPipelineEnabled: Bool {
        didSet { defaults.set(suggestionPipelineEnabled, forKey: Keys.suggestionPipelineEnabled) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.adaptivePrefetchEnabled = defaults.object(forKey: Keys.adaptiveEnabled) as? Bool ?? true

        let savedMode = defaults.string(forKey: Keys.modeOverride) ?? PrefetchModeOverride.auto.rawValue
        self.prefetchModeOverride = PrefetchModeOverride(rawValue: savedMode) ?? .auto

        self.wifiPrefetchCount = defaults.object(forKey: Keys.wifiCount) as? Int ?? 6
        self.cellularPrefetchCount = defaults.object(forKey: Keys.cellularCount) as? Int ?? 2
        self.wifiPrefetchConcurrency = defaults.object(forKey: Keys.wifiConcurrency) as? Int ?? 3
        self.cellularPrefetchConcurrency = defaults.object(forKey: Keys.cellularConcurrency) as? Int ?? 1
        self.metricsEnabled = defaults.object(forKey: Keys.metricsEnabled) as? Bool ?? true
        self.suggestionPipelineEnabled = defaults.object(forKey: Keys.suggestionPipelineEnabled) as? Bool ?? true
    }
}
