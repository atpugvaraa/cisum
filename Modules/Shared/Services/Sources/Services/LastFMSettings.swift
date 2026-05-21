import Foundation
import Observation

@Observable
@MainActor
public final class LastFMSettings {
    public static let shared = LastFMSettings()

    private enum Keys {
        static let enabled = "lastfm.scrobbling.enabled"
        static let localHistoryEnabled = "lastfm.local_history.enabled"
        static let isConnected = "lastfm.is_connected"
        static let lastfmUsername = "lastfm.username"
    }

    private let defaults: UserDefaults

    public var enabled: Bool {
        didSet { persistToDefaults() }
    }

    public var localHistoryEnabled: Bool {
        didSet { persistToDefaults() }
    }

    /// Whether the user has an active Last.fm connection on the server.
    /// Updated from server status checks; also cached locally.
    public var isConnected: Bool {
        didSet { defaults.set(isConnected, forKey: Keys.isConnected) }
    }

    /// The connected Last.fm username, if any.
    public var lastfmUsername: String? {
        didSet { defaults.set(lastfmUsername, forKey: Keys.lastfmUsername) }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.enabled = defaults.object(forKey: Keys.enabled) as? Bool ?? false
        self.localHistoryEnabled = defaults.object(forKey: Keys.localHistoryEnabled) as? Bool ?? true
        self.isConnected = defaults.bool(forKey: Keys.isConnected)
        self.lastfmUsername = defaults.string(forKey: Keys.lastfmUsername)
    }

    public var configuration: LastFMConfiguration {
        LastFMConfiguration(enabled: enabled)
    }

    private func persistToDefaults() {
        defaults.set(enabled, forKey: Keys.enabled)
        defaults.set(localHistoryEnabled, forKey: Keys.localHistoryEnabled)
    }

    /// Clear connection state (used on disconnect).
    public func clearConnection() {
        isConnected = false
        lastfmUsername = nil
        defaults.removeObject(forKey: Keys.isConnected)
        defaults.removeObject(forKey: Keys.lastfmUsername)
    }

    /// Update connection state from server status response.
    public func updateConnectionStatus(connected: Bool, username: String?) {
        isConnected = connected
        lastfmUsername = username
    }
}
