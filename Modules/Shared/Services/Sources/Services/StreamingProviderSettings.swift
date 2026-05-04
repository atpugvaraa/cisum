import Foundation
import Observation

@Observable
@MainActor
public final class StreamingProviderSettings {
    public static let shared = StreamingProviderSettings()

    private enum Keys {
        static let spotifyClientID = "streaming.spotify.client_id"
        static let spotifyClientSecret = "streaming.spotify.client_secret"
        static let spotifyPreferAnonymousFallback = "streaming.spotify.prefer_anonymous_fallback"
    }

    private let defaults: UserDefaults

    public var spotifyClientID: String {
        didSet {
            defaults.set(spotifyClientID, forKey: Keys.spotifyClientID)
        }
    }

    public var spotifyClientSecret: String {
        didSet {
            defaults.set(spotifyClientSecret, forKey: Keys.spotifyClientSecret)
        }
    }

    public var spotifyPreferAnonymousFallback: Bool {
        didSet {
            defaults.set(spotifyPreferAnonymousFallback, forKey: Keys.spotifyPreferAnonymousFallback)
        }
    }

    public var hasSpotifyCredentials: Bool {
        !spotifyClientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !spotifyClientSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var spotifyModeLabel: String {
        hasSpotifyCredentials ? "Official" : "Anonymous Fallback"
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.spotifyClientID = defaults.string(forKey: Keys.spotifyClientID) ?? ""
        self.spotifyClientSecret = defaults.string(forKey: Keys.spotifyClientSecret) ?? ""
        self.spotifyPreferAnonymousFallback = defaults.object(forKey: Keys.spotifyPreferAnonymousFallback) as? Bool ?? true
    }

    public func clearSpotifyCredentials() {
        spotifyClientID = ""
        spotifyClientSecret = ""
    }
}

