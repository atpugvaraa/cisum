import Foundation
import Models
import SwiftData

@MainActor
public final class ListeningHistoryStore {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func startSession(
        mediaID: String,
        title: String,
        artist: String,
        album: String? = nil,
        artworkURL: URL? = nil,
        streamingService: String,
        startedAt: Date = .now
    ) -> ListeningHistoryEntry {
        let entry = ListeningHistoryEntry(
            mediaID: mediaID,
            title: title,
            artist: artist,
            album: album,
            artworkURL: artworkURL?.absoluteString,
            streamingService: streamingService,
            startedAt: startedAt
        )
        context.insert(entry)
        try? context.save()
        return entry
    }

    public func finishSession(
        _ entry: ListeningHistoryEntry,
        endedAt: Date = .now,
        listenedSeconds: Double,
        wasScrobbled: Bool,
        scrobbledAt: Date? = nil
    ) {
        entry.endedAt = endedAt
        entry.listenedSeconds = max(listenedSeconds, 0)
        entry.wasScrobbled = wasScrobbled
        entry.scrobbledAt = scrobbledAt
        try? context.save()
    }

    public func markScrobbled(_ entry: ListeningHistoryEntry, scrobbledAt: Date = .now) {
        entry.wasScrobbled = true
        entry.scrobbledAt = scrobbledAt
        try? context.save()
    }
}

public extension ListeningHistoryStore {
    static var preview: ListeningHistoryStore {
        let container = try! ModelContainer(
            for: Schema([ListeningHistoryEntry.self]),
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        return ListeningHistoryStore(context: ModelContext(container))
    }
}
