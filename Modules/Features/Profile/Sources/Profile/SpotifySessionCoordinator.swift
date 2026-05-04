import Foundation
import Observation
import Security

#if canImport(SpotifySDK)
import SpotifySDK
#endif

#if canImport(SpotifySDK)
actor SpotifyKeychainTokenStore: SpotifyTokenStore {
    private struct StoredTokens: Codable {
        let accessTokenValue: String
        let accessTokenType: String
        let accessTokenExpiresAt: Date

        let clientTokenValue: String?
        let clientTokenExpiresAt: Date?

        let refreshToken: String?
        let scope: [String]
        let clientID: String?
        let spotifyWebPlayerCookie: String?
        let isAnonymous: Bool

        init(tokens: SpotifySessionTokens) {
            self.accessTokenValue = tokens.accessToken.value
            self.accessTokenType = tokens.accessToken.tokenType
            self.accessTokenExpiresAt = tokens.accessToken.expiresAt
            self.clientTokenValue = tokens.clientToken?.value
            self.clientTokenExpiresAt = tokens.clientToken?.expiresAt
            self.refreshToken = tokens.refreshToken
            self.scope = Array(tokens.scope).sorted()
            self.clientID = tokens.clientID
            self.spotifyWebPlayerCookie = tokens.spotifyWebPlayerCookie
            self.isAnonymous = tokens.isAnonymous
        }

        func asDomainTokens() -> SpotifySessionTokens {
            SpotifySessionTokens(
                accessToken: SpotifyAccessToken(
                    value: accessTokenValue,
                    tokenType: accessTokenType,
                    expiresAt: accessTokenExpiresAt
                ),
                clientToken: clientTokenValue.map { SpotifyClientToken(value: $0, expiresAt: clientTokenExpiresAt) },
                refreshToken: refreshToken,
                scope: Set(scope),
                clientID: clientID,
                spotifyWebPlayerCookie: spotifyWebPlayerCookie,
                isAnonymous: isAnonymous
            )
        }
    }

    enum StoreError: LocalizedError {
        case invalidData

        var errorDescription: String? {
            switch self {
            case .invalidData:
                return "Unable to decode Spotify session tokens from secure storage."
            }
        }
    }

    private let service = "com.cisum.spotify.session"
    private let account = "authenticated.tokens.v1"

    func loadTokens() async throws -> SpotifySessionTokens? {
        guard let data = try readData() else {
            return nil
        }

        guard let payload = try? JSONDecoder().decode(StoredTokens.self, from: data) else {
            throw StoreError.invalidData
        }

        return payload.asDomainTokens()
    }

    func saveTokens(_ tokens: SpotifySessionTokens) async throws {
        let payload = StoredTokens(tokens: tokens)
        let data = try JSONEncoder().encode(payload)
        try writeData(data)
    }

    func clearTokens() async throws {
        try deleteData()
    }

    private func readData() throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }

        return result as? Data
    }

    private func writeData(_ data: Data) throws {
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }

        if updateStatus != errSecItemNotFound {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(updateStatus))
        }

        var insertQuery = baseQuery
        for (key, value) in attributes {
            insertQuery[key] = value
        }

        let insertStatus = SecItemAdd(insertQuery as CFDictionary, nil)
        guard insertStatus == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(insertStatus))
        }
    }

    private func deleteData() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }
}

@Observable
@MainActor
final class SpotifySessionCoordinator {
    static let shared = SpotifySessionCoordinator()

    private let tokenStore: SpotifyKeychainTokenStore

    public private(set) var session: SpotifyOAuthSession?
    public private(set) var sdk: SpotifySDK?
    public private(set) var accountProfile: SpotifyAccountProfile?

    public var isPresentingExtractor = false
    public private(set) var pendingMode: SpotifyAuthMode = .anonymous
    public private(set) var isRestoringSession: Bool = false
    public private(set) var didAttemptRestore: Bool = false
    public private(set) var lastErrorMessage: String?
    public private(set) var sessionRevision = UUID()

    init(tokenStore: SpotifyKeychainTokenStore = SpotifyKeychainTokenStore()) {
        self.tokenStore = tokenStore
    }

    var isAuthenticated: Bool {
        session?.isAuthenticated == true
    }

    var sessionStatusLabel: String {
        if session?.tokens?.isAnonymous == true {
            return "Anonymous"
        }

        if accountProfile != nil {
            return "Connected"
        }

        if isAuthenticated {
            return "Connected"
        }

        if isRestoringSession {
            return "Restoring"
        }

        return "Not Connected"
    }

    var accountDescriptor: String {
        if let profile = accountProfile {
            return profile.displayName
        }

        guard let tokens = session?.tokens else {
            return "No active Spotify session."
        }

        if tokens.isAnonymous {
            return "Anonymous guest session"
        }

        return "Personal account connected"
    }

    func restoreSessionIfNeeded() async {
        guard !didAttemptRestore else {
            return
        }

        didAttemptRestore = true
        isRestoringSession = true
        defer { isRestoringSession = false }

        // Try to load cached tokens. We don't know the mode yet, so we try to reconstruct.
        if let cached = try? await tokenStore.loadTokens() {
            let mode: SpotifyAuthMode = cached.isAnonymous ? .anonymous : .authenticated
            let restoredSession = SpotifyOAuthSession(mode: mode, tokenStore: tokenStore)
            self.session = restoredSession
            self.sdk = SpotifySDK(session: restoredSession, tokenStore: tokenStore)
            await restoredSession.restoreFromCache()
            await refreshAccountProfile()
        }
    }

    func beginSession(mode: SpotifyAuthMode) {
        lastErrorMessage = nil
        pendingMode = mode
        accountProfile = nil
        
        let previousSession = session
        let newSession = SpotifyOAuthSession(mode: mode, tokenStore: tokenStore)
        self.session = newSession
        self.sdk = nil
        self.isPresentingExtractor = true
        newSession.beginExtraction()

        Task {
            await previousSession?.signOut()
        }
    }

    func completeSession(tokens: SpotifySessionTokens) {
        guard let session else { return }
        lastErrorMessage = nil
        
        // Update the session with new tokens (this might be a partial update)
        session.handleExtractedTokens(tokens)
        
        // Re-initialize the SDK with the updated session if needed
        if self.sdk == nil {
            self.sdk = SpotifySDK(session: session, tokenStore: tokenStore)
        }

        Task {
            await self.refreshAccountProfile()
        }
        
        // Non-eager dismissal:
        // For authenticated mode, we wait for both tokens to ensure Pathfinder (search) works immediately.
        // For anonymous mode, accessToken is usually enough to start, but we still prefer having both.
        let hasBoth = tokens.accessToken.value.count > 0 && (tokens.clientToken?.value.count ?? 0) > 0
        
        if hasBoth || tokens.isAnonymous {
            // Give it a tiny bit of time to settle if we just got the second token
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                await MainActor.run {
                    self.isPresentingExtractor = false
                    self.sessionRevision = UUID()
                }
            }
        }
    }

    func cancelSessionSetup() {
        let pendingSession = session
        session = nil
        sdk = nil
        accountProfile = nil
        isPresentingExtractor = false
        Task {
            await pendingSession?.signOut()
        }
    }

    func signOut() async {
        lastErrorMessage = nil
        let currentSession = session
        session = nil
        sdk = nil
        accountProfile = nil
        isPresentingExtractor = false
        await currentSession?.signOut()
    }

    func refreshAccountProfile() async {
        guard let sdk else {
            accountProfile = nil
            return
        }

        guard session?.tokens?.isAnonymous == false else {
            accountProfile = nil
            return
        }

        do {
            accountProfile = try await sdk.account.profileAttributes()
        } catch {
            accountProfile = nil
        }
    }
}
#else
@Observable
@MainActor
final class SpotifySessionCoordinator {
    static let shared = SpotifySessionCoordinator()

    private(set) var isAuthenticated: Bool = false
    private(set) var sessionStatusLabel: String = "Unavailable"
    private(set) var accountDescriptor: String = "SpotifySDK is not linked to this target."
    private(set) var accountProfile: Any? = nil

    func restoreSessionIfNeeded() async {}
    func beginSessionExtraction() {}
    func completeSessionExtraction(tokens: Any) {}
    func failSessionExtraction(_ message: String) {}
    func signOut() async {}
}
#endif
