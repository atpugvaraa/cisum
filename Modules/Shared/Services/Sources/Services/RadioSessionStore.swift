import Foundation

@MainActor
public final class RadioSessionStore {
    public struct CachedTrack: Codable, Sendable, Equatable {
        public let videoID: String
        public let title: String
        public let artist: String
        public let albumName: String?
        public let thumbnailURLString: String?
        public let isExplicit: Bool

        public var thumbnailURL: URL? {
            guard let string = thumbnailURLString else { return nil }
            return URL(string: string)
        }

        public init(
            videoID: String,
            title: String,
            artist: String,
            albumName: String? = nil,
            thumbnailURLString: String? = nil,
            isExplicit: Bool = false
        ) {
            self.videoID = videoID
            self.title = title
            self.artist = artist
            self.albumName = albumName
            self.thumbnailURLString = thumbnailURLString
            self.isExplicit = isExplicit
        }
    }

    public struct Session: Codable, Sendable {
        public let seedVideoID: String
        public let playlistID: String?
        public let continuationToken: String?
        public let tracks: [CachedTrack]
        public let updatedAt: Date

        public init(
            seedVideoID: String,
            playlistID: String? = nil,
            continuationToken: String? = nil,
            tracks: [CachedTrack] = [],
            updatedAt: Date = .now
        ) {
            self.seedVideoID = seedVideoID
            self.playlistID = playlistID
            self.continuationToken = continuationToken
            self.tracks = tracks
            self.updatedAt = updatedAt
        }
    }

    public static let shared = RadioSessionStore()

    private enum StorageKeys {
        static let sessions = "playback.radio.sessions.bySeed"
    }

    private enum Policy {
        static let maxSessions = 64
        static let maxTracksPerSession = 200
        static let maxAge: TimeInterval = 60 * 60 * 24 * 14
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var sessionsBySeed: [String: Session] = [:]

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadFromDefaults()
        pruneExpiredSessions()
    }

    public func session(forSeedVideoID seedVideoID: String) -> Session? {
        guard let session = sessionsBySeed[seedVideoID] else {
            return nil
        }

        if Date().timeIntervalSince(session.updatedAt) > Policy.maxAge {
            sessionsBySeed[seedVideoID] = nil
            persistToDefaults()
            return nil
        }

        return session
    }

    public func save(session: Session) {
        let trimmedSeed = session.seedVideoID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSeed.isEmpty else { return }

        let normalizedTracks = Array(session.tracks.prefix(Policy.maxTracksPerSession))
        let normalized = Session(
            seedVideoID: trimmedSeed,
            playlistID: session.playlistID,
            continuationToken: session.continuationToken,
            tracks: normalizedTracks,
            updatedAt: .now
        )

        sessionsBySeed[trimmedSeed] = normalized
        enforceSessionLimitIfNeeded()
        persistToDefaults()
    }

    public func clear(seedVideoID: String) {
        sessionsBySeed[seedVideoID] = nil
        persistToDefaults()
    }

    private func loadFromDefaults() {
        guard let raw = defaults.data(forKey: StorageKeys.sessions),
              let decoded = try? decoder.decode([String: Session].self, from: raw) else {
            sessionsBySeed = [:]
            return
        }

        sessionsBySeed = decoded
    }

    private func persistToDefaults() {
        guard let encoded = try? encoder.encode(sessionsBySeed) else {
            return
        }
        defaults.set(encoded, forKey: StorageKeys.sessions)
    }

    private func pruneExpiredSessions() {
        let now = Date()
        sessionsBySeed = sessionsBySeed.filter { _, session in
            now.timeIntervalSince(session.updatedAt) <= Policy.maxAge
        }
        enforceSessionLimitIfNeeded()
        persistToDefaults()
    }

    private func enforceSessionLimitIfNeeded() {
        guard sessionsBySeed.count > Policy.maxSessions else { return }

        let sorted = sessionsBySeed.values.sorted { lhs, rhs in
            lhs.updatedAt > rhs.updatedAt
        }
        let keep = Set(sorted.prefix(Policy.maxSessions).map(\.seedVideoID))
        sessionsBySeed = sessionsBySeed.filter { keep.contains($0.key) }
    }
}
