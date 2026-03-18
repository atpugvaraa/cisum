import Foundation

actor PlaybackMetricsStore {
    static let shared = PlaybackMetricsStore()

    struct Snapshot: Sendable {
        let cacheHitRate: Double
        let avgResolveMs: Double
        let avgTapToPlayMs: Double
        let resolveSampleCount: Int
        let tapToPlaySampleCount: Int
    }

    private var resolveDurations: [Double] = []
    private var tapToPlayDurations: [Double] = []
    private var cacheHitCount: Int = 0
    private var cacheMissCount: Int = 0
    private let maxSamples = 500

    func recordResolve(cacheHit: Bool, durationMs: Double) {
        if cacheHit {
            cacheHitCount += 1
        } else {
            cacheMissCount += 1
        }
        resolveDurations.append(durationMs)
        trim()
    }

    func recordTapToPlay(durationMs: Double) {
        tapToPlayDurations.append(durationMs)
        trim()
    }

    func snapshot() -> Snapshot {
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

    func reset() {
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
