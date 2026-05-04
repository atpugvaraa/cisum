import Foundation

public actor PlaybackMetricsStore {
    public static let shared = PlaybackMetricsStore()

    public struct Snapshot: Sendable {
        public let cacheHitRate: Double
        public let avgResolveMs: Double
        public let avgTapToPlayMs: Double
        public let resolveSampleCount: Int
        public let tapToPlaySampleCount: Int
        
        public init(cacheHitRate: Double, avgResolveMs: Double, avgTapToPlayMs: Double, resolveSampleCount: Int, tapToPlaySampleCount: Int) {
            self.cacheHitRate = cacheHitRate
            self.avgResolveMs = avgResolveMs
            self.avgTapToPlayMs = avgTapToPlayMs
            self.resolveSampleCount = resolveSampleCount
            self.tapToPlaySampleCount = tapToPlaySampleCount
        }
    }

    private var resolveDurations: [Double] = []
    private var tapToPlayDurations: [Double] = []
    private var cacheHitCount: Int = 0
    private var cacheMissCount: Int = 0
    private let maxSamples = 500
    
    public init() {}

    public func recordResolve(cacheHit: Bool, durationMs: Double) {
        if cacheHit {
            cacheHitCount += 1
        } else {
            cacheMissCount += 1
        }
        resolveDurations.append(durationMs)
        trim()
    }

    public func recordTapToPlay(durationMs: Double) {
        tapToPlayDurations.append(durationMs)
        trim()
    }

    public func snapshot() -> Snapshot {
        let total = cacheHitCount + cacheMissCount
        let hitRate = total > 0 ? Double(cacheHitCount) / Double(total) : 0
        let avgResolve = resolveDurations.isEmpty ? 0 : resolveDurations.reduce(0, +) / Double(resolveDurations.count)
        let avgTap = tapToPlayDurations.isEmpty ? 0 : tapToPlayDurations.reduce(0, +) / Double(tapToPlayDurations.count)

        return Snapshot(
            cacheHitRate: hitRate,
            avgResolveMs: avgResolve,
            avgTapToPlayMs: avgTap,
            resolveSampleCount: resolveDurations.count,
            tapToPlaySampleCount: tapToPlayDurations.count
        )
    }

    public func reset() {
        resolveDurations.removeAll()
        tapToPlayDurations.removeAll()
        cacheHitCount = 0
        cacheMissCount = 0
    }

    private func trim() {
        if resolveDurations.count > maxSamples {
            resolveDurations.removeFirst(resolveDurations.count - maxSamples)
        }
        if tapToPlayDurations.count > maxSamples {
            tapToPlayDurations.removeFirst(tapToPlayDurations.count - maxSamples)
        }
    }
}
