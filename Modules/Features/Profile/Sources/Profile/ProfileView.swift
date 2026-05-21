//
//  ProfileView.swift
//  cisum
//
//  Created by Aarav Gupta on 15/03/26.
//

import SwiftUI
import YouTubeSDK
import DesignSystem
import Services

#if canImport(SpotifySDK)
import SpotifySDK
#endif

public struct ProfileView: View {
    public init() {}

    @Environment(ProviderServices.self) private var providerServices
    @Environment(PlaybackServices.self) private var playbackServices
    @Environment(UserServices.self) private var userServices
    @Environment(\.router) private var router
    
    private var youtube: YouTube { providerServices.youtube }
    private var streamingProviderSettings: StreamingProviderSettings { playbackServices.streamingProviderSettings }
    private var spotifyCoordinator: SpotifySessionCoordinator { userServices.spotifySessionCoordinator }

    @State private var showOAuthSheet: Bool = false
    @State private var hasOAuthSession: Bool = false
    @State private var isSigningOutSpotify: Bool = false
    @State private var isSigningOutCisum: Bool = false

    public var body: some View {
        ZStack {
            Color.black
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    profileHeader

                    cisumAccountCard

                    spotifyProfileCard

                    profileStatusCard

                    Button {
                        showOAuthSheet = true
                    } label: {
                        Label(
                            hasOAuthSession ? "Reconnect Google Account" : "Login with Google",
                            systemImage: "person.badge.key"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    if hasOAuthSession {
                        Button(role: .destructive) {
                            Task {
                                await YouTubeOAuthClient.logout()
                                refreshSessionState()
                            }
                        } label: {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }

                    Text(
                        "This profile screen is intentionally lightweight for now and will be expanded in a later pass."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                .padding()
            }
            .safeAreaPadding(.top, 80)
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showOAuthSheet) {
            YouTubeOAuthDeviceFlowView { _ in
                Task { @MainActor in
                    _ = await youtube.ensureAccessToken()
                    refreshSessionState()
                    showOAuthSheet = false
                }
            } onCancel: {
                showOAuthSheet = false
            }
        }
        #if os(iOS) && canImport(SpotifySDK)
        .sheet(isPresented: Bindable(spotifyCoordinator).isPresentingExtractor) {
            SpotifySessionExtractorSheet(coordinator: spotifyCoordinator)
        }
        #endif
        .onAppear {
            refreshSessionState()
        }
    }

    private var profileHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Profile")
                .font(.largeTitle.weight(.semibold))
            Text("Connect your Google account for better personalized search and recommendations.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - cisum Account Card

    private var cisumAccountCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: userServices.authService.isAuthenticated ? "person.crop.circle.badge.checkmark" : "person.crop.circle")
                    .font(.title2)
                    .foregroundStyle(userServices.authService.isAuthenticated ? .blue : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("cisum Account")
                        .font(.headline)
                    if userServices.authService.isAuthenticated {
                        Text(userServices.authService.user?.emailAddresses.first?.emailAddress ?? "Signed In")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("Using as Guest")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if userServices.authService.isAuthenticated {
                    Text("Connected")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.15), in: Capsule())
                        .foregroundStyle(.blue)
                } else {
                    Text("Guest")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1), in: Capsule())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)

            Divider()

            VStack(spacing: 12) {
                if userServices.authService.isAuthenticated {
                    if let fullName = userServices.authService.user?.fullName, !fullName.isEmpty {
                        HStack {
                            Text("Name")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(fullName)
                                .font(.subheadline)
                        }
                    }

                    Button(role: .destructive) {
                        Task {
                            isSigningOutCisum = true
                            await userServices.authService.signOut()
                            userServices.analyticsService.reset()
                            isSigningOutCisum = false
                        }
                    } label: {
                        HStack {
                            Text("Sign Out")
                            if isSigningOutCisum {
                                Spacer()
                                ProgressView().controlSize(.small)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(isSigningOutCisum)
                } else {
                    VStack(spacing: 12) {
                        Text("Sign in to connect Last.fm, sync listening data, and link Spotify")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        Button {
                            router.navigate(to: .login)
                        } label: {
                            Text("Sign In")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }

    private var profileStatusCard: some View {
        HStack(spacing: 12) {
            Image(
                systemName: hasOAuthSession
                    ? "checkmark.seal.fill" : "person.crop.circle.badge.exclamationmark"
            )
            .font(.title2)
            .foregroundStyle(hasOAuthSession ? .green : .orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(hasOAuthSession ? "Signed In" : "Not Signed In")
                    .font(.headline)
                Text(
                    hasOAuthSession
                        ? "OAuth session active." : "Sign in to improve search relevance."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }

    private func refreshSessionState() {
        Task {
            let hasToken = await YouTubeOAuthClient().hasValidToken()
            await MainActor.run {
                hasOAuthSession = hasToken
            }
        }
    }

    // MARK: - Spotify Section

    private var spotifyProfileCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "music.note")
                    .font(.title2)
                    .foregroundStyle(spotifyCoordinator.isAuthenticated ? .green : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Spotify")
                        .font(.headline)
                    Text(
                        spotifyCoordinator.isAuthenticated
                            ? spotifyCoordinator.accountDescriptor : "Not Signed In"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }

                Spacer()

                Text(spotifyCoordinator.sessionStatusLabel)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        spotifyCoordinator.isAuthenticated
                            ? Color.green.opacity(0.15)
                            : Color.secondary.opacity(0.1),
                        in: Capsule()
                    )
                    .foregroundStyle(
                        spotifyCoordinator.isAuthenticated ? .green : .secondary
                    )
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)

            Divider()

            VStack(spacing: 12) {
                if spotifyCoordinator.isAuthenticated {
                    Button(role: .destructive) {
                        Task {
                            isSigningOutSpotify = true
                            await spotifyCoordinator.signOut()
                            isSigningOutSpotify = false
                        }
                    } label: {
                        HStack {
                            Text("Disconnect Spotify")
                            if isSigningOutSpotify {
                                Spacer()
                                ProgressView().controlSize(.small)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(isSigningOutSpotify)
                } else {
                    #if os(iOS) && canImport(SpotifySDK)
                        Button {
                            spotifyCoordinator.beginSession(mode: .authenticated)
                        } label: {
                            Label("Connect with Spotify", systemImage: "person.badge.key")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(spotifyCoordinator.isRestoringSession)

                        if let error = spotifyCoordinator.lastErrorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }

                        Toggle(
                            "Use Anonymous Fallback",
                            isOn: Bindable(streamingProviderSettings).spotifyPreferAnonymousFallback
                        )
                        Text(
                            "When enabled, Spotify search uses a temporary public session. Some results may be limited."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    #else
                        Text("Spotify is unavailable on this platform.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    #endif
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
}

#if os(iOS) && canImport(SpotifySDK)
    struct SpotifySessionExtractorSheet: View {
        @Bindable var coordinator: SpotifySessionCoordinator
        @Environment(\.dismiss) private var dismiss

        var body: some View {
            VStack(spacing: 0) {
                header
                Divider()
                if coordinator.session != nil {
                    SpotifyTokenExtractorView(
                        mode: coordinator.pendingMode,
                        onTokensExtracted: { tokens in
                            coordinator.completeSession(tokens: tokens)
                        }
                    )
                } else {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Preparing Spotify session…")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(Color(.systemBackground))

        }

        private var header: some View {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(
                        coordinator.pendingMode == .anonymous ? "Use as guest" : "Login to Spotify"
                    )
                    .font(.headline)
                    Text(coordinator.accountDescriptor)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(
                        coordinator.pendingMode == .anonymous
                            ? "Anonymous tokens will be used for public search."
                            : "Signing in will replace the current session with your Spotify account."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Cancel") {
                    coordinator.cancelSessionSetup()
                }
                .buttonStyle(.bordered)
            }
            .padding(20)
            .background(Color.secondary.opacity(0.05))
        }
    }
#endif

#if DEBUG
    #Preview {
        ProfileView()
    }
#endif
