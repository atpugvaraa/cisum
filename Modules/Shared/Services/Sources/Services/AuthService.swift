import Foundation
import Observation
import ClerkKit

@Observable
@MainActor
public final class AuthService {
    private enum Keys {
        static let guestMode = "auth.guest_mode"
    }

    public private(set) var session: Session?
    public private(set) var user: User?
    public private(set) var isLoading: Bool = false
    public private(set) var error: Error?
    public private(set) var isGuestMode: Bool

    public var isAuthenticated: Bool {
        session != nil && user != nil
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isGuestMode = defaults.bool(forKey: Keys.guestMode)
        Task {
            await checkSession()
        }
    }

    public func checkSession() async {
        session = Clerk.shared.session
        user = Clerk.shared.user
        error = nil
    }

    // MARK: - Guest Mode

    public func enterGuestMode() {
        isGuestMode = true
        defaults.set(true, forKey: Keys.guestMode)
    }

    public func exitGuestMode() {
        isGuestMode = false
        defaults.removeObject(forKey: Keys.guestMode)
    }

    // MARK: - Sign In / Up

    public func signInWithEmailPassword(email: String, password: String) async -> Bool {
        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await Clerk.shared.auth.signInWithPassword(identifier: email, password: password)
            session = Clerk.shared.session
            user = Clerk.shared.user
            error = nil
            return true
        } catch {
            self.error = error
            return false
        }
    }
    
    public func signInWithGoogle() async -> Bool {
        isLoading = true
        defer { isLoading = false }
        
        do {
            _ = try await Clerk.shared.auth.signInWithOAuth(provider: .google)
            session = Clerk.shared.session
            user = Clerk.shared.user
            error = nil
            return true
        } catch {
            self.error = error
            return false
        }
    }

    public func signUpWithEmailPassword(email: String, password: String, firstName: String?, lastName: String?) async -> Bool {
        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await Clerk.shared.auth.signUp(
                emailAddress: email,
                password: password,
                firstName: firstName,
                lastName: lastName
            )
            session = Clerk.shared.session
            user = Clerk.shared.user
            error = nil
            return true
        } catch {
            self.error = error
            return false
        }
    }

    // MARK: - Sign Out

    public func signOut() async {
        do {
            try await Clerk.shared.auth.signOut()
            session = nil
            user = nil
            error = nil
            exitGuestMode()
        } catch {
            self.error = error
        }
    }

    public func getSessionToken() async -> String? {
        do {
            return try await Clerk.shared.session?.getToken()
        } catch {
            self.error = error
            return nil
        }
    }
}

public extension User {
    var fullName: String {
        let first = firstName ?? ""
        let last = lastName ?? ""
        let combined = "\(first) \(last)".trimmingCharacters(in: .whitespaces)
        return combined.isEmpty ? "Unknown" : combined
    }
}
