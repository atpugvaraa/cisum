import SwiftUI
import Services

public struct LoginView: View {
    enum Step {
        case email, password, profile
    }

    @Environment(UserServices.self) private var userServices

    @State private var step: Step = .email
    @State private var isNewUser = false
    @State private var email = ""
    @State private var password = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var username = ""
    @State private var errorMessage: String?

    private var authService: AuthService { userServices.authService }
    private var supabaseService: SupabaseService { userServices.supabaseService }
    private var analyticsService: AnalyticsService { userServices.analyticsService }

    private static let bg = Color(red: 32/255, green: 34/255, blue: 46/255)
    private static let fieldBg = Color(red: 40/255, green: 43/255, blue: 58/255)
    private static let highlights = Color(red: 162/255, green: 133/255, blue: 80/255)

    public init() {}

    public var body: some View {
        ZStack {
            Self.bg.ignoresSafeArea()

            VStack(spacing: 16) {
                Spacer(minLength: 300)

                VStack(alignment: .leading, spacing: 24) {
                    HStack(spacing: 12) {
                        if step != .email {
                            Button {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                    goBack()
                                }
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .transition(.opacity.combined(with: .scale(scale: 0.8)))
                        }

                        Text(title)
                            .font(.title2)
                            .foregroundStyle(.white)
                            .fontWeight(.bold)
                            .fontWidth(.expanded)
                            .contentTransition(.numericText())
                    }

                    Group {
                        switch step {
                        case .email:
                            emailFields
                        case .password:
                            passwordFields
                        case .profile:
                            profileFields
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))

                    if let errorMessage {
                        errorBanner(errorMessage)
                    }

                    actionButton
                }

                if step == .email {
                    socialSection
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                Spacer()
                
                if step == .email {
                    continueAsGuest
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding([.horizontal, .bottom], 24)
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: step)
        .onChange(of: email) { _, _ in isNewUser = false }
        .onAppear { prefetchHomeData() }
        .loginTabBarHidden()
    }

    // MARK: - Step Fields

    private var emailFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("Email")
            TextField("", text: $email)
                .textFieldStyle(.plain)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                #endif
                .textContentType(.emailAddress)
                .padding(12)
                .background(Self.fieldBg)
                .cornerRadius(6)
                .foregroundColor(.white)
        }
    }

    private var passwordFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("Password")
            SecureField("", text: $password)
                .textFieldStyle(.plain)
                .textContentType(isNewUser ? .newPassword : .password)
                .padding(12)
                .background(Self.fieldBg)
                .cornerRadius(6)
                .foregroundColor(.white)
        }
    }

    private var profileFields: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("First Name")
                TextField("First", text: $firstName)
                    .textFieldStyle(.plain)
                    #if os(iOS)
                    .textInputAutocapitalization(.words)
                    #endif
                    .padding(12)
                    .background(Self.fieldBg)
                    .cornerRadius(6)
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("Last Name")
                TextField("Last", text: $lastName)
                    .textFieldStyle(.plain)
                    #if os(iOS)
                    .textInputAutocapitalization(.words)
                    #endif
                    .padding(12)
                    .background(Self.fieldBg)
                    .cornerRadius(6)
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("Username")
                TextField("@username", text: $username)
                    .textFieldStyle(.plain)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .padding(12)
                    .background(Self.fieldBg)
                    .cornerRadius(6)
                    .foregroundColor(.white)
            }
        }
    }

    // MARK: - Shared Components

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.title2)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .fontWidth(.expanded)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.red)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    private var actionButton: some View {
        Button(action: handleAction) {
            Group {
                if authService.isLoading {
                    HStack(spacing: 8) {
                        ProgressView().progressViewStyle(.circular).tint(.white)
                        Text(loadingLabel)
                    }
                } else {
                    Text(actionLabel)
                        .contentTransition(.numericText())
                }
            }
            .font(.system(size: 16, weight: .semibold))
            .fontWidth(.expanded)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isActionDisabled ? Self.highlights.opacity(0.4) : Self.highlights)
            .foregroundColor(.white)
            .cornerRadius(50)
            .disabled(isActionDisabled)
            .animation(.easeInOut(duration: 0.2), value: isActionDisabled)
        }
        .buttonStyle(.plain)
    }

    private var socialSection: some View {
        VStack(spacing: 12) {
            HStack {
                Rectangle().fill(Color.gray.opacity(0.3)).frame(height: 1)
                Text("or").foregroundColor(.gray).font(.system(size: 14))
                Rectangle().fill(Color.gray.opacity(0.3)).frame(height: 1)
            }

            Button(action: handleAppleSignIn) {
                HStack {
                    Image(systemName: "applelogo").font(.system(size: 20))
                    Text("Continue with Apple").font(.system(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.white)
                .foregroundColor(.black)
                .cornerRadius(50)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            Button(action: handleGoogleSignIn) {
                HStack {
                    Image("googlelogo")
                        .resizable()
                        .frame(width: 18, height: 18)
                    
                    Text("Continue with Google").font(.system(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.white)
                .foregroundColor(.black)
                .cornerRadius(50)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
    }
    
    private var continueAsGuest: some View {
        Button(action: { authService.enterGuestMode() }) {
            Text("Continue as guest")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Self.highlights.opacity(0.8))
                .underline(color: Self.highlights.opacity(0.4))
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    // MARK: - Computed Labels

    private var title: String {
        switch step {
        case .email:    ""
        case .password: isNewUser ? "Create a password" : "Enter your password"
        case .profile:  "Almost there"
        }
    }

    private var actionLabel: String {
        switch step {
        case .email:    "Next"
        case .password: "Continue"
        case .profile:  "Create Account"
        }
    }

    private var loadingLabel: String {
        switch step {
        case .email:    "Next"
        case .password: isNewUser ? "Continue" : "Signing In..."
        case .profile:  "Creating Account..."
        }
    }

    private var isActionDisabled: Bool {
        let busy = authService.isLoading
        switch step {
        case .email:
            return busy || email.isEmpty
        case .password:
            return busy || password.isEmpty
        case .profile:
            return busy || firstName.isEmpty || username.isEmpty
        }
    }

    // MARK: - Navigation

    private func goBack() {
        errorMessage = nil
        switch step {
        case .email: break
        case .password:
            password = ""
            step = .email
        case .profile:
            firstName = ""
            lastName = ""
            username = ""
            step = .password
        }
    }

    // MARK: - Actions

    private func handleAction() {
        errorMessage = nil
        switch step {
        case .email:
            withAnimation { step = .password }
        case .password where isNewUser:
            withAnimation { step = .profile }
        case .password:
            attemptSignIn()
        case .profile:
            signUp()
        }
    }

    private func attemptSignIn() {
        Task {
            let result = await authService.signInWithEmailPassword(email: email, password: password)
            switch result {
            case .success:
                await syncAndTrack(signup: false)
            case .accountNotFound:
                isNewUser = true
                withAnimation { step = .profile }
            case .failed(let message):
                errorMessage = message
            }
        }
    }

    private func signUp() {
        Task {
            let ok = await authService.signUpWithEmailPassword(
                email: email, password: password,
                firstName: firstName, lastName: lastName.isEmpty ? nil : lastName
            )
            if ok { await syncAndTrack(signup: true) }
            else { errorMessage = authService.error?.localizedDescription ?? "Sign-up failed" }
        }
    }

    private func handleAppleSignIn() {
        errorMessage = nil
        Task {
            let ok = await authService.signInWithApple()
            if ok { await syncAndTrack(signup: false) }
            else { errorMessage = authService.error?.localizedDescription ?? "Apple sign-in failed" }
        }
    }

    private func handleGoogleSignIn() {
        errorMessage = nil
        Task {
            let ok = await authService.signInWithGoogle()
            if ok { await syncAndTrack(signup: false) }
            else { errorMessage = authService.error?.localizedDescription ?? "Google sign-in failed" }
        }
    }

    private func syncAndTrack(signup: Bool) async {
        guard let user = authService.user else { return }
        do {
            try await supabaseService.syncUserFromClerk(
                clerkUserId: user.id,
                email: user.emailAddresses.first?.emailAddress,
                fullName: user.fullName,
                username: user.username,
                imageUrl: user.imageUrl
            )
        } catch {
            errorMessage = "Failed to sync: \(error.localizedDescription)"
            return
        }
        analyticsService.identify(userId: user.id, properties: [
            "email": user.emailAddresses.first?.emailAddress ?? "",
            "name": user.fullName,
            "signup": signup
        ])
        analyticsService.captureEvent(
            signup ? "user_signed_up" : "user_signed_in",
            properties: ["email": email]
        )
    }

    private func prefetchHomeData() {
        Task.detached(priority: .utility) {
            // await homeDataService.prefetch()
        }
    }
}

// MARK: - View Modifiers
private extension View {
    @ViewBuilder
    func loginTabBarHidden() -> some View {
        #if os(iOS)
        self.toolbar(.hidden, for: .tabBar)
        #else
        self
        #endif
    }
}

#Preview {
    LoginView()
        .environment(UserServices(
            spotifySessionCoordinator: SpotifySessionCoordinator(),
            authService: AuthService(checksSessionOnInit: false),
            supabaseService: SupabaseService(),
            analyticsService: AnalyticsService()
        ))
}
