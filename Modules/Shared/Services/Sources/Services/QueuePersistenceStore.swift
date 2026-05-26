import Foundation
import Models

public final class QueuePersistenceStore {
    public static let lastQueueKey = "__last_active_queue__"

    private let fileManager: FileManager
    private let fileURL: URL

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager

        let directory = fileManager
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? fileManager.temporaryDirectory
            .appendingPathComponent("Cisum", isDirectory: true)
            .appendingPathComponent("Queue", isDirectory: true)

        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        self.fileURL = directory.appendingPathComponent("last_queue.json")
    }

    public func saveLastQueue(itemsJSON: String, currentIndex: Int) {
        let payload = Payload(itemsJSON: itemsJSON, currentIndex: currentIndex, updatedAt: .now)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }

    public func loadLastQueue() -> (itemsJSON: String, currentIndex: Int)? {
        guard let data = try? Data(contentsOf: fileURL),
              let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            return nil
        }

        return (payload.itemsJSON, payload.currentIndex)
    }

    private struct Payload: Codable {
        let itemsJSON: String
        let currentIndex: Int
        let updatedAt: Date
    }
}
