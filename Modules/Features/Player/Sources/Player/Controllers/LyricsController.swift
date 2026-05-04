import Foundation
import Observation
import Models
import Services

@Observable
@MainActor
public final class LyricsController {
    public var state: LyricsState = .idle
    public var syncedLines: [TimedLyricLine] = []
    public var plainText: String?
    public var isVisible: Bool = false
    public var currentLineIndex: Int?
    public var attribution: String?
    
    public init() {}
    
    public func updateCurrentLine(for time: Double) {
        guard state == .synced else { return }
        let index = syncedLines.lastIndex { $0.timestamp <= time }
        if currentLineIndex != index {
            currentLineIndex = index
        }
    }
    
    public func reset() {
        state = .idle
        syncedLines = []
        plainText = nil
        currentLineIndex = nil
        attribution = nil
    }
    
    public func loadLyrics(synced: [TimedLyricLine], plain: String?, attribution: String?) {
        if !synced.isEmpty {
            self.syncedLines = synced
            self.state = .synced
        } else if let plain = plain, !plain.isEmpty {
            self.plainText = plain
            self.state = .plain
        } else {
            self.state = .unavailable("No lyrics available for this track.")
        }
        self.attribution = attribution
    }
    
    public func setLoading() {
        self.state = .loading
    }
}
