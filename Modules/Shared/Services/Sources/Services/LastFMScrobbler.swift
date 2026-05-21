import Foundation

// MARK: - Data Types

public struct LastFMPlaybackItem: Sendable, Equatable {
    public let mediaID: String
    public let title: String
    public let artist: String
    public let album: String?
    public let artworkURL: URL?
    public let trackNumber: UInt?
    public let durationSeconds: UInt?
    public let contextURL: URL?
    public let mbid: String?
    public let albumArtist: String?

    public init(
        mediaID: String,
        title: String,
        artist: String,
        album: String? = nil,
        artworkURL: URL? = nil,
        trackNumber: UInt? = nil,
        durationSeconds: UInt? = nil,
        contextURL: URL? = nil,
        mbid: String? = nil,
        albumArtist: String? = nil
    ) {
        self.mediaID = mediaID
        self.title = title
        self.artist = artist
        self.album = album
        self.artworkURL = artworkURL
        self.trackNumber = trackNumber
        self.durationSeconds = durationSeconds
        self.contextURL = contextURL
        self.mbid = mbid
        self.albumArtist = albumArtist
    }
}

public struct LastFMConfiguration: Sendable, Equatable {
    public var enabled: Bool

    public init(enabled: Bool = false) {
        self.enabled = enabled
    }
}

// MARK: - Server Response Types

public struct LastFMConnectionStatus: Sendable, Codable {
    public let connected: Bool
    public let lastfmUsername: String?
    public let connectedAt: String?
    public let pendingFlowId: String?
    public let pendingFlowExpiresAt: String?
}

public struct LastFMConnectionFlow: Sendable, Codable {
    public let flowId: String
    public let authorizeUrl: String
    public let expiresAt: String
}

public struct LastFMConnectionResult: Sendable, Codable {
    public let connected: Bool
    public let lastfmUsername: String?
    public let connectedAt: String?
}

// MARK: - Scrobbler

public actor LastFMScrobbler {
    private static let baseURL = "https://cisum.studio"

    private var configuration = LastFMConfiguration()
    private var recentPlays: [LastFMPlaybackItem] = []
    private let authService: AuthService

    public init(configuration: LastFMConfiguration = .init(), authService: AuthService) {
        self.configuration = configuration
        self.authService = authService
    }

    public func configure(_ configuration: LastFMConfiguration) {
        self.configuration = configuration
    }

    public var isEnabled: Bool {
        configuration.enabled
    }

    // MARK: - Playback Scrobbling

    public func recordNowPlaying(_ item: LastFMPlaybackItem) async throws {
        guard isEnabled else { return }
        guard let token = await authService.getSessionToken() else { return }

        let payload = buildPayload(from: item)
        let body: [String: Any] = ["action": "nowPlaying", "payload": payload]

        try await postToLastFMAPI(body: body, token: token)
        recentPlays.append(item)
    }

    public func scrobble(_ item: LastFMPlaybackItem, playedAt date: Date = .now) async throws {
        guard isEnabled else { return }
        guard let token = await authService.getSessionToken() else { return }

        var payload = buildPayload(from: item)
        payload["playedAt"] = ISO8601DateFormatter().string(from: date)
        let body: [String: Any] = ["action": "scrobble", "payload": payload]

        try await postToLastFMAPI(body: body, token: token)
        recentPlays.append(item)
    }

    public func recentPlayHistory() -> [LastFMPlaybackItem] {
        recentPlays
    }

    // MARK: - Connection Management

    public func checkConnectionStatus() async throws -> LastFMConnectionStatus {
        guard let token = await authService.getSessionToken() else {
            return LastFMConnectionStatus(
                connected: false,
                lastfmUsername: nil,
                connectedAt: nil,
                pendingFlowId: nil,
                pendingFlowExpiresAt: nil
            )
        }

        let url = URL(string: "\(Self.baseURL)/api/lastfm")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, data: data)
        return try JSONDecoder().decode(LastFMConnectionStatus.self, from: data)
    }

    public func startConnection() async throws -> LastFMConnectionFlow {
        guard let token = await authService.getSessionToken() else {
            throw LastFMAPIError.notAuthenticated
        }

        let body: [String: Any] = ["action": "start"]
        let data = try await postToLastFMAPIReturningData(body: body, token: token)
        return try JSONDecoder().decode(LastFMConnectionFlow.self, from: data)
    }

    public func completeConnection(flowId: String) async throws -> LastFMConnectionResult {
        guard let token = await authService.getSessionToken() else {
            throw LastFMAPIError.notAuthenticated
        }

        let body: [String: Any] = ["action": "complete", "flowId": flowId]
        let data = try await postToLastFMAPIReturningData(body: body, token: token)
        return try JSONDecoder().decode(LastFMConnectionResult.self, from: data)
    }

    public func disconnect() async throws {
        guard let token = await authService.getSessionToken() else {
            throw LastFMAPIError.notAuthenticated
        }

        let body: [String: Any] = ["action": "disconnect"]
        try await postToLastFMAPI(body: body, token: token)
    }

    // MARK: - HTTP Helpers

    private func buildPayload(from item: LastFMPlaybackItem) -> [String: Any] {
        var payload: [String: Any] = [
            "mediaId": item.mediaID,
            "title": item.title,
            "artist": item.artist,
        ]
        if let album = item.album { payload["album"] = album }
        if let artworkURL = item.artworkURL { payload["artworkUrl"] = artworkURL.absoluteString }
        if let trackNumber = item.trackNumber { payload["trackNumber"] = trackNumber }
        if let durationSeconds = item.durationSeconds { payload["durationSeconds"] = durationSeconds }
        if let contextURL = item.contextURL { payload["contextUrl"] = contextURL.absoluteString }
        if let mbid = item.mbid { payload["mbid"] = mbid }
        if let albumArtist = item.albumArtist { payload["albumArtist"] = albumArtist }
        return payload
    }

    @discardableResult
    private func postToLastFMAPI(body: [String: Any], token: String) async throws -> Data {
        try await postToLastFMAPIReturningData(body: body, token: token)
    }

    private func postToLastFMAPIReturningData(body: [String: Any], token: String) async throws -> Data {
        let url = URL(string: "\(Self.baseURL)/api/lastfm")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, data: data)
        return data
    }

    private func validateHTTPResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LastFMAPIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage: String
            if let errorJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = errorJSON["error"] as? String {
                errorMessage = message
            } else {
                errorMessage = "Last.fm API request failed with status \(httpResponse.statusCode)"
            }
            throw LastFMAPIError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
    }
}

// MARK: - Errors

public enum LastFMAPIError: Error, LocalizedError {
    case notAuthenticated
    case invalidResponse
    case serverError(statusCode: Int, message: String)

    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Sign in to your cisum account to use Last.fm"
        case .invalidResponse:
            return "Received an invalid response from the server"
        case .serverError(_, let message):
            return message
        }
    }
}