import Foundation
import Observation
import Security
import WebKit

#if canImport(SpotifySDK)
    import SpotifySDK
#endif

#if canImport(SpotifySDK)
    public actor SpotifyKeychainTokenStore: SpotifyTokenStore {
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
                    clientToken: clientTokenValue.map {
                        SpotifyClientToken(value: $0, expiresAt: clientTokenExpiresAt)
                    },
                    refreshToken: refreshToken,
                    scope: Set(scope),
                    clientID: clientID,
                    spotifyWebPlayerCookie: spotifyWebPlayerCookie,
                    isAnonymous: isAnonymous
                )
            }
        }

        public enum StoreError: LocalizedError {
            case invalidData

            public var errorDescription: String? {
                switch self {
                case .invalidData:
                    return "Unable to decode Spotify session tokens from secure storage."
                }
            }
        }

        private let service = "cisum.spotify.session"
        private let account: String

        public init(account: String = "authenticated.tokens.v1") {
            self.account = account
        }

        public func loadTokens() async throws -> SpotifySessionTokens? {
            guard let data = try readData() else {
                return nil
            }

            guard let payload = try? JSONDecoder().decode(StoredTokens.self, from: data) else {
                throw StoreError.invalidData
            }

            return payload.asDomainTokens()
        }

        public func saveTokens(_ tokens: SpotifySessionTokens) async throws {
            let payload = StoredTokens(tokens: tokens)
            let data = try JSONEncoder().encode(payload)
            try writeData(data)
        }

        public func clearTokens() async throws {
            try deleteData()
        }

        private func readData() throws -> Data? {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne,
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
                kSecAttrAccount as String: account,
            ]

            let attributes: [String: Any] = [
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
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
                kSecAttrAccount as String: account,
            ]

            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
            }
        }
    }

    @Observable
    @MainActor
    public final class SpotifySessionCoordinator {
        public static let shared = SpotifySessionCoordinator()

        public private(set) var session: SpotifyOAuthSession?
        public private(set) var sdk: SpotifySDK?
        public private(set) var accountProfile: SpotifyAccountProfile?

        // Dedicated fallback session for anonymous search when authenticated
        public private(set) var anonymousFallbackSession: SpotifyOAuthSession?
        public private(set) var anonymousFallbackSdk: SpotifySDK?

        // Maintain references to both stores so we can check if they exist independently
        private let authenticatedTokenStore = SpotifyKeychainTokenStore(
            account: "authenticated.tokens.v1")
        private let anonymousTokenStore = SpotifyKeychainTokenStore(account: "anonymous.tokens.v1")

        public private(set) var cacheDelegate: (any SpotifyCacheDelegate)?

        public var isPresentingExtractor = false
        public private(set) var pendingMode: SpotifyAuthMode = .anonymous
        public private(set) var isRestoringSession: Bool = false
        public private(set) var didAttemptRestore: Bool = false
        public private(set) var lastErrorMessage: String?
        public private(set) var sessionRevision = UUID()

        public init() {}

        public func setCacheDelegate(_ delegate: any SpotifyCacheDelegate) {
            self.cacheDelegate = delegate
            if let session, self.sdk != nil {
                let activeTokenStore =
                    session.mode == .authenticated ? authenticatedTokenStore : anonymousTokenStore
                self.sdk = SpotifySDK(
                    session: session, tokenStore: activeTokenStore, cacheDelegate: delegate)
            }
            if let fallbackSession = self.anonymousFallbackSession {
                self.anonymousFallbackSdk = SpotifySDK(
                    session: fallbackSession, tokenStore: anonymousTokenStore,
                    cacheDelegate: delegate)
            }
        }

        public var isAuthenticated: Bool {
            session?.isAuthenticated == true
        }

        /// True if a session exists, even if the token is temporarily expired (pending refresh).
        /// Use this for UI that should show "Connected" while a silent refresh is in progress.
        public var hasSession: Bool {
            session?.tokens != nil
        }

        public var sessionStatusLabel: String {
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

        public var accountDescriptor: String {
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

        public func restoreSessionIfNeeded() async {
            guard !didAttemptRestore else {
                return
            }

            didAttemptRestore = true
            isRestoringSession = true
            defer { isRestoringSession = false }

            // Try to load authenticated tokens first
            if let cached = try? await authenticatedTokenStore.loadTokens() {
                let restoredSession = SpotifyOAuthSession(
                    mode: .authenticated, tokenStore: authenticatedTokenStore)
                self.session = restoredSession
                self.sdk = SpotifySDK(
                    session: restoredSession, tokenStore: authenticatedTokenStore,
                    cacheDelegate: cacheDelegate)

                // If we are authenticated, we also initialize the fallback session so it can refresh silently
                let fallbackSession = SpotifyOAuthSession(
                    mode: .anonymous, tokenStore: anonymousTokenStore)
                self.anonymousFallbackSession = fallbackSession
                self.anonymousFallbackSdk = SpotifySDK(
                    session: fallbackSession, tokenStore: anonymousTokenStore,
                    cacheDelegate: cacheDelegate)
                await fallbackSession.restoreFromCache()

                await restoredSession.restoreFromCache()
                await refreshAccountProfile()
            }
            // Fallback to anonymous tokens if they exist and user hasn't explicitly logged in
            else if let cached = try? await anonymousTokenStore.loadTokens() {
                let restoredSession = SpotifyOAuthSession(
                    mode: .anonymous, tokenStore: anonymousTokenStore)
                self.session = restoredSession
                self.sdk = SpotifySDK(
                    session: restoredSession, tokenStore: anonymousTokenStore,
                    cacheDelegate: cacheDelegate)
                await restoredSession.restoreFromCache()
            }
        }

        public func beginSession(mode: SpotifyAuthMode) {
            lastErrorMessage = nil
            pendingMode = mode
            accountProfile = nil

            let previousSession = session
            let activeTokenStore =
                mode == .authenticated ? authenticatedTokenStore : anonymousTokenStore
            let newSession = SpotifyOAuthSession(mode: mode, tokenStore: activeTokenStore)
            self.session = newSession
            self.sdk = nil

            if mode == .authenticated {
                let fallbackSession = SpotifyOAuthSession(
                    mode: .anonymous, tokenStore: anonymousTokenStore)
                self.anonymousFallbackSession = fallbackSession
                self.anonymousFallbackSdk = SpotifySDK(
                    session: fallbackSession, tokenStore: anonymousTokenStore,
                    cacheDelegate: cacheDelegate)
                Task { await fallbackSession.restoreFromCache() }
            } else {
                self.anonymousFallbackSession = nil
                self.anonymousFallbackSdk = nil
            }

            self.isPresentingExtractor = true
            newSession.beginExtraction()

            Task {
                await previousSession?.signOut()
            }
        }

        public func completeSession(tokens: SpotifySessionTokens) {
            print(
                "🚀 [SpotifySessionCoordinator] completeSession. tokens.isAnonymous: \(tokens.isAnonymous), pendingMode: \(pendingMode)"
            )
            guard let session else { return }
            lastErrorMessage = nil

            // Update the session with new tokens (this might be a partial update)
            session.handleExtractedTokens(tokens)

            let activeTokenStore =
                session.mode == .authenticated ? authenticatedTokenStore : anonymousTokenStore

            // Re-initialize the SDK with the updated session if needed
            if self.sdk == nil {
                self.sdk = SpotifySDK(
                    session: session, tokenStore: activeTokenStore, cacheDelegate: cacheDelegate)
            }

            Task {
                await self.refreshAccountProfile()
            }

            // Non-eager dismissal:
            // For authenticated mode, we wait for both tokens to ensure Pathfinder (search) works immediately.
            // For anonymous mode, accessToken is usually enough to start, but we still prefer having both.
            let hasBoth =
                tokens.accessToken.value.count > 0 && (tokens.clientToken?.value.count ?? 0) > 0

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

        public func cancelSessionSetup() {
            let pendingSession = session
            session = nil
            sdk = nil
            accountProfile = nil
            isPresentingExtractor = false
            Task {
                await pendingSession?.signOut()
            }
        }

        public func signOut() async {
            lastErrorMessage = nil
            let currentSession = session
            session = nil
            sdk = nil
            accountProfile = nil
            isPresentingExtractor = false
            await currentSession?.signOut()

            let currentFallback = anonymousFallbackSession
            anonymousFallbackSession = nil
            anonymousFallbackSdk = nil
            await currentFallback?.signOut()

            // Also wipe the isolated anonymous WebKit data store to ensure no accidental auth leaks
            await MainActor.run {
                if #available(iOS 17.0, macOS 14.0, *) {
                    let store = WKWebsiteDataStore(
                        forIdentifier: UUID(uuidString: "5AF3D87F-646C-49D6-9C49-E8D56A496E37")!)
                    store.removeData(
                        ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                        modifiedSince: Date.distantPast, completionHandler: {})
                }
            }
        }

        public func refreshAccountProfile() async {
            guard let sdk else {
                accountProfile = nil
                return
            }

            print(
                "🚀 [SpotifySessionCoordinator] refreshAccountProfile called. tokens.isAnonymous: \(String(describing: session?.tokens?.isAnonymous))"
            )

            guard session?.tokens?.isAnonymous == false else {
                print(
                    "🚀 [SpotifySessionCoordinator] Bailing out of profile fetch because tokens are marked anonymous."
                )
                accountProfile = nil
                return
            }

            do {
                accountProfile = try await sdk.account.profileAttributes()
                print(
                    "🚀 [SpotifySessionCoordinator] Successfully fetched profile: \(accountProfile?.displayName ?? "nil")"
                )
            } catch {
                print("🔴 [SpotifySessionCoordinator] Failed to fetch account profile: \(error)")
                accountProfile = nil
            }
        }
    }
#else
    @Observable
    @MainActor
    public final class SpotifySessionCoordinator {
        public static let shared = SpotifySessionCoordinator()

        public private(set) var isAuthenticated: Bool = false
        public private(set) var sessionStatusLabel: String = "Unavailable"
        public private(set) var accountDescriptor: String =
            "SpotifySDK is not linked to this target."
        public private(set) var accountProfile: Any? = nil

        public init() {}

        public func restoreSessionIfNeeded() async {}
        public func beginSessionExtraction() {}
        public func completeSessionExtraction(tokens: Any) {}
        public func failSessionExtraction(_ message: String) {}
        public func signOut() async {}
    }
#endif
