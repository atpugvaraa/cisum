import Foundation

public enum LyricsState: Equatable {
    case idle
    case loading
    case synced
    case plain
    case unavailable(String)
}

public struct TimedLyricLine: Identifiable, Equatable {
    public let id: String
    public let timestamp: TimeInterval
    public let text: String

    public init(timestamp: TimeInterval, text: String) {
        self.timestamp = timestamp
        self.text = text
        self.id = "\(timestamp)-\(text)"
    }
}
