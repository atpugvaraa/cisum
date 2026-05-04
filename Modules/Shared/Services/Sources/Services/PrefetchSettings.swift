import SwiftUI
import Foundation
import Utilities

public enum PrefetchModeOverride: String, CaseIterable, Identifiable, Sendable {
    case auto
    case metadataOnly
    case aggressiveWarmup

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .auto: return "Auto"
        case .metadataOnly: return "Metadata Only"
        case .aggressiveWarmup: return "Aggressive Warmup"
        }
    }
}

@Observable
@MainActor
public final class PrefetchSettings {
    public static let shared = PrefetchSettings()

    private let persistenceScheduler = DebouncedWorkScheduler(delay: .milliseconds(250))

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

    public var adaptivePrefetchEnabled: Bool {
        didSet { schedulePersistence() }
    }

    public var prefetchModeOverride: PrefetchModeOverride {
        didSet { schedulePersistence() }
    }

    public var wifiPrefetchCount: Int {
        didSet { schedulePersistence() }
    }

    public var cellularPrefetchCount: Int {
        didSet { schedulePersistence() }
    }

    public var wifiPrefetchConcurrency: Int {
        didSet { schedulePersistence() }
    }

    public var cellularPrefetchConcurrency: Int {
        didSet { schedulePersistence() }
    }

    public var metricsEnabled: Bool {
        didSet { schedulePersistence() }
    }

    public var suggestionPipelineEnabled: Bool {
        didSet { schedulePersistence() }
    }

    public init(defaults: UserDefaults = .standard) {
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

    public func flushPendingWrites() {
        persistenceScheduler.cancel()
        persistToDefaults()
    }

    private func schedulePersistence() {
        persistenceScheduler.schedule { [weak self] in
            self?.persistToDefaults()
        }
    }

    private func persistToDefaults() {
        defaults.set(adaptivePrefetchEnabled, forKey: Keys.adaptiveEnabled)
        defaults.set(prefetchModeOverride.rawValue, forKey: Keys.modeOverride)
        defaults.set(wifiPrefetchCount, forKey: Keys.wifiCount)
        defaults.set(cellularPrefetchCount, forKey: Keys.cellularCount)
        defaults.set(wifiPrefetchConcurrency, forKey: Keys.wifiConcurrency)
        defaults.set(cellularPrefetchConcurrency, forKey: Keys.cellularConcurrency)
        defaults.set(metricsEnabled, forKey: Keys.metricsEnabled)
        defaults.set(suggestionPipelineEnabled, forKey: Keys.suggestionPipelineEnabled)
    }
}
