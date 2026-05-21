import SwiftUI
import Services

public struct LoginView: View {
    @Environment(UserServices.self) private var userServices

    @State private var isSignUp: Bool = false
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var errorMessage: String?

    private var authService: AuthService { userServices.authService }
    private var supabaseService: SupabaseService { userServices.supabaseService }
    private var analyticsService: AnalyticsService { userServices.analyticsService }

    public init() {}

    public var body: some View {
        ZStack {
            // Background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.15),
                    Color(red: 0.05, green: 0.05, blue: 0.1)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text(isSignUp ? "Create Account" : "Welcome Back")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)

                    Text(isSignUp ? "Sign up to get started" : "Sign in to your account")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Google Sign In
                Button(action: {
                    handleGoogleSignIn()
                }) {
                    HStack {
                        Image(systemName: "g.circle.fill")
                            .font(.system(size: 20))
                        Text(isSignUp ? "Sign up with Google" : "Sign in with Google")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.white)
                .foregroundColor(.black)
                .cornerRadius(8)
                
                HStack {
                    Rectangle().fill(Color.gray.opacity(0.3)).frame(height: 1)
                    Text("or").foregroundColor(.gray).font(.system(size: 14))
                    Rectangle().fill(Color.gray.opacity(0.3)).frame(height: 1)
                }

                VStack(spacing: 12) {
                    // Email Field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Email")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.gray)

                        TextField("Enter your email", text: $email)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .padding(12)
                            .background(Color(red: 0.15, green: 0.15, blue: 0.2))
                            .cornerRadius(8)
                            .foregroundColor(.white)
                    }

                    // Sign-up only: First and Last Name
                    if isSignUp {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("First Name")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.gray)

                                TextField("First name", text: $firstName)
                                    .textInputAutocapitalization(.words)
                                    .padding(12)
                                    .background(Color(red: 0.15, green: 0.15, blue: 0.2))
                                    .cornerRadius(8)
                                    .foregroundColor(.white)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Last Name")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.gray)

                                TextField("Last name", text: $lastName)
                                    .textInputAutocapitalization(.words)
                                    .padding(12)
                                    .background(Color(red: 0.15, green: 0.15, blue: 0.2))
                                    .cornerRadius(8)
                                    .foregroundColor(.white)
                            }
                        }
                    }

                    // Password Field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Password")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.gray)

                        SecureField("Enter your password", text: $password)
                            .padding(12)
                            .background(Color(red: 0.15, green: 0.15, blue: 0.2))
                            .cornerRadius(8)
                            .foregroundColor(.white)
                    }
                }

                // Error Message
                if let errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.red)
                        Text(errorMessage)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.red)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }

                // Action Button
                Button(action: handleAuthAction) {
                    if authService.isLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                            Text(isSignUp ? "Creating Account..." : "Signing In...")
                        }
                    } else {
                        Text(isSignUp ? "Create Account" : "Sign In")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .disabled(authService.isLoading || email.isEmpty || password.isEmpty || (isSignUp && firstName.isEmpty))
                .opacity(authService.isLoading || email.isEmpty || password.isEmpty || (isSignUp && firstName.isEmpty) ? 0.6 : 1)

                Spacer()

                // Toggle Sign-in/Sign-up
                HStack(spacing: 4) {
                    Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)

                    Button(action: {
                        withAnimation {
                            isSignUp.toggle()
                            errorMessage = nil
                            clearFields()
                        }
                    }) {
                        Text(isSignUp ? "Sign In" : "Sign Up")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                }

                // Use as Guest
                Button(action: {
                    authService.enterGuestMode()
                }) {
                    Text("Continue without an account")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray.opacity(0.8))
                        .underline(color: .gray.opacity(0.4))
                }
                .padding(.top, 4)
            }
            .padding(24)
        }
    }

    private func handleAuthAction() {
        errorMessage = nil

        Task {
            let success: Bool

            if isSignUp {
                success = await authService.signUpWithEmailPassword(
                    email: email,
                    password: password,
                    firstName: firstName,
                    lastName: lastName.isEmpty ? nil : lastName
                )
            } else {
                success = await authService.signInWithEmailPassword(
                    email: email,
                    password: password
                )
            }

            if success {
                // Sync user to Supabase
                if let clerkUser = authService.user {
                    do {
                        try await supabaseService.syncUserFromClerk(
                            clerkUserId: clerkUser.id,
                            email: clerkUser.emailAddresses.first?.emailAddress,
                            fullName: clerkUser.fullName,
                            username: clerkUser.username,
                            imageUrl: clerkUser.imageUrl
                        )
                    } catch {
                        errorMessage = "Failed to sync user data: \(error.localizedDescription)"
                        return
                    }

                    // Identify user in PostHog
                    analyticsService.identify(
                        userId: clerkUser.id,
                        properties: [
                            "email": clerkUser.emailAddresses.first?.emailAddress ?? "",
                            "name": clerkUser.fullName,
                            "signup": isSignUp
                        ]
                    )

                    // Capture sign-in/sign-up event
                    analyticsService.captureEvent(
                        isSignUp ? "user_signed_up" : "user_signed_in",
                        properties: ["email": email]
                    )
                }
            } else if let error = authService.error {
                errorMessage = error.localizedDescription
            } else {
                errorMessage = isSignUp ? "Sign-up failed" : "Sign-in failed"
            }
        }
    }
    
    private func handleGoogleSignIn() {
        errorMessage = nil
        Task {
            let success = await authService.signInWithGoogle()
            if success {
                if let clerkUser = authService.user {
                    do {
                        try await supabaseService.syncUserFromClerk(
                            clerkUserId: clerkUser.id,
                            email: clerkUser.emailAddresses.first?.emailAddress,
                            fullName: clerkUser.fullName,
                            username: clerkUser.username,
                            imageUrl: clerkUser.imageUrl
                        )
                    } catch {
                        errorMessage = "Failed to sync user data: \(error.localizedDescription)"
                        return
                    }

                    analyticsService.identify(
                        userId: clerkUser.id,
                        properties: [
                            "email": clerkUser.emailAddresses.first?.emailAddress ?? "",
                            "name": clerkUser.fullName,
                            "signup": isSignUp
                        ]
                    )

                    analyticsService.captureEvent(
                        isSignUp ? "user_signed_up_google" : "user_signed_in_google",
                        properties: ["email": clerkUser.emailAddresses.first?.emailAddress ?? ""]
                    )
                }
            } else if let error = authService.error {
                errorMessage = error.localizedDescription
            } else {
                errorMessage = isSignUp ? "Google Sign-up failed" : "Google Sign-in failed"
            }
        }
    }

    private func clearFields() {
        email = ""
        password = ""
        firstName = ""
        lastName = ""
    }
}
