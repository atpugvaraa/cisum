import Foundation

public actor PlaybackURLEphemeralStore {
    public struct EphemeralEntry: Sendable {
        public let candidates: [PlaybackCandidate]
        public let savedAt: Date
        public let expiresAt: Date?
    }

    public static let shared = PlaybackURLEphemeralStore()

    private var store: [String: EphemeralEntry] = [:]

    public init() {}

    public func save(mediaID: String, candidates: [PlaybackCandidate], expiresAt: Date?) {
        let entry = EphemeralEntry(candidates: candidates, savedAt: .now, expiresAt: expiresAt)
        store[mediaID] = entry
    }

    public func candidates(for mediaID: String, maxAge: TimeInterval) -> [PlaybackCandidate]? {
        guard let entry = store[mediaID] else { return nil }

        // Check explicit expiresAt first.
        if let expires = entry.expiresAt, Date() >= expires { return nil }

        // Check age relative to savedAt
        if Date().timeIntervalSince(entry.savedAt) > maxAge { return nil }

        return entry.candidates
    }

    public func invalidate(mediaID: String) {
        store[mediaID] = nil
    }

    public func pruneExpired(now: Date = Date()) {
        for (key, entry) in store {
            if let expires = entry.expiresAt, now >= expires {
                store[key] = nil
                continue
            }

            // default TTL guard — keep reasonable
            if now.timeIntervalSince(entry.savedAt) > (60 * 60 * 24) {
                store[key] = nil
            }
        }
    }
}
