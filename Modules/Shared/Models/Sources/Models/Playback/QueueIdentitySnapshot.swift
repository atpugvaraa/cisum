import Foundation

// Canonical queue identity snapshot used for persistence. Keep this minimal and
// stable; the runtime may use a richer representation but it must be serializable.
public struct QueueIdentitySnapshot: Codable, Hashable, Sendable {
    public let canonicalID: String
    public let activeRepresentationKey: String?
    public let candidateSnapshotJSON: String?

    public init(canonicalID: String, activeRepresentationKey: String? = nil, candidateSnapshotJSON: String? = nil) {
        self.canonicalID = canonicalID
        self.activeRepresentationKey = activeRepresentationKey
        self.candidateSnapshotJSON = candidateSnapshotJSON
    }
}
