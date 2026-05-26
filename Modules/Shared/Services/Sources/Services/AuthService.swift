import Foundation
import Observation
import ClerkKit

@Observable
@MainActor
public final class AuthService {
    private enum Keys {
        static let guestMode = "auth.guest_mode"
    }

    public enum SignInResult {
        case success
        case accountNotFound
        case failed(String)
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

    public init(defaults: UserDefaults = .standard, checksSessionOnInit: Bool = true) {
        self.defaults = defaults
        self.isGuestMode = defaults.bool(forKey: Keys.guestMode)
        if checksSessionOnInit {
            Task {
                await checkSession()
            }
        }
    }

    public func checkSession() async {
        session = Clerk.shared.session
        user = Clerk.shared.user
        error = nil
        print("[AuthService] checkSession: authenticated=\(isAuthenticated), user=\(user?.id ?? "nil")")
    }

    // MARK: - Guest Mode

    public func enterGuestMode() {
        isGuestMode = true
        defaults.set(true, forKey: Keys.guestMode)
        print("[AuthService] Entered guest mode")
    }

    public func exitGuestMode() {
        isGuestMode = false
        defaults.removeObject(forKey: Keys.guestMode)
        print("[AuthService] Exited guest mode")
    }

    // MARK: - Sign In / Up

    public func signInWithEmailPassword(email: String, password: String) async -> SignInResult {
        isLoading = true
        defer { isLoading = false }
        print("[AuthService] signIn: attempting with email=\(email)")

        do {
            _ = try await Clerk.shared.auth.signInWithPassword(identifier: email, password: password)
            session = Clerk.shared.session
            user = Clerk.shared.user
            error = nil
            print("[AuthService] signIn: ✅ success, user=\(user?.id ?? "nil")")
            return .success
        } catch {
            self.error = error
            let reflected = String(reflecting: error)
            let localized = error.localizedDescription
            let errorType = type(of: error)
            print("[AuthService] signIn: ❌ failed")
            print("[AuthService] signIn: errorType = \(errorType)")
            print("[AuthService] signIn: localizedDescription = \(localized)")
            print("[AuthService] signIn: reflected = \(reflected)")
            
            let containsIdentifier = reflected.contains("form_identifier_not_found")
            print("[AuthService] signIn: containsIdentifier = \(containsIdentifier)")
            
            if containsIdentifier {
                print("[AuthService] signIn: → returning .accountNotFound")
                return .accountNotFound
            }
            print("[AuthService] signIn: → returning .failed")
            return .failed(localized)
        }
    }

    public func signInWithApple() async -> Bool {
        isLoading = true
        defer { isLoading = false }
        print("[AuthService] signInWithApple: attempting")

        do {
            _ = try await Clerk.shared.auth.signInWithApple()
            session = Clerk.shared.session
            user = Clerk.shared.user
            error = nil
            print("[AuthService] signInWithApple: ✅ success")
            return true
        } catch {
            self.error = error
            print("[AuthService] signInWithApple: ❌ \(error.localizedDescription)")
            print("[AuthService] signInWithApple: reflected = \(String(reflecting: error))")
            return false
        }
    }

    public func signInWithGoogle() async -> Bool {
        isLoading = true
        defer { isLoading = false }
        print("[AuthService] signInWithGoogle: attempting")

        do {
            _ = try await Clerk.shared.auth.signInWithOAuth(provider: .google)
            session = Clerk.shared.session
            user = Clerk.shared.user
            error = nil
            print("[AuthService] signInWithGoogle: ✅ success")
            return true
        } catch {
            self.error = error
            print("[AuthService] signInWithGoogle: ❌ \(error.localizedDescription)")
            print("[AuthService] signInWithGoogle: reflected = \(String(reflecting: error))")
            return false
        }
    }

    public func signUpWithEmailPassword(email: String, password: String, firstName: String?, lastName: String?) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        print("[AuthService] signUp: attempting with email=\(email), firstName=\(firstName ?? "nil")")

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
            print("[AuthService] signUp: ✅ success, user=\(user?.id ?? "nil")")
            return true
        } catch {
            self.error = error
            print("[AuthService] signUp: ❌ \(error.localizedDescription)")
            print("[AuthService] signUp: reflected = \(String(reflecting: error))")
            return false
        }
    }

    // MARK: - Sign Out

    public func signOut() async {
        print("[AuthService] signOut: attempting")
        do {
            try await Clerk.shared.auth.signOut()
            session = nil
            user = nil
            error = nil
            exitGuestMode()
            print("[AuthService] signOut: ✅ success")
        } catch {
            self.error = error
            print("[AuthService] signOut: ❌ \(error.localizedDescription)")
        }
    }

    public func getSessionToken() async -> String? {
        do {
            let token = try await Clerk.shared.session?.getToken()
            print("[AuthService] getSessionToken: \(token != nil ? "✅ got token" : "⚠️ nil")")
            return token
        } catch {
            self.error = error
            print("[AuthService] getSessionToken: ❌ \(error.localizedDescription)")
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
