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
    
    private var youtube: YouTube { providerServices.youtube }
    private var streamingProviderSettings: StreamingProviderSettings { playbackServices.streamingProviderSettings }
    private var spotifyCoordinator: SpotifySessionCoordinator { userServices.spotifySessionCoordinator }

    @State private var showLoginSheet: Bool = false
    @State private var hasStoredSession: Bool = false
    @State private var isSigningOutSpotify: Bool = false

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                profileHeader

                spotifyProfileCard

                profileStatusCard

                Button {
                    showLoginSheet = true
                } label: {
                    Label(
                        hasStoredSession ? "Reconnect Google Account" : "Login with Google",
                        systemImage: "person.badge.key"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                if hasStoredSession {
                    Button(role: .destructive) {
                        Task {
                            await YouTubeOAuthClient.logout()
                            youtube.cookies = nil
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
        .safeAreaPadding(.top)
        .sheet(isPresented: $showLoginSheet) {
            GoogleLoginView { cookies in
                Task { @MainActor in
                    await YouTubeOAuthClient.saveCookies(cookies)
                    youtube.cookies = cookies
                    refreshSessionState()
                    showLoginSheet = false
                }
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

    private var profileStatusCard: some View {
        HStack(spacing: 12) {
            Image(
                systemName: hasStoredSession
                    ? "checkmark.seal.fill" : "person.crop.circle.badge.exclamationmark"
            )
            .font(.title2)
            .foregroundStyle(hasStoredSession ? .green : .orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(hasStoredSession ? "Signed In" : "Not Signed In")
                    .font(.headline)
                Text(
                    hasStoredSession
                        ? "Active cookie session detected." : "Sign in to improve search relevance."
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
            let cookies = await YouTubeOAuthClient.loadCookies()
            await MainActor.run {
                hasStoredSession = !(cookies?.isEmpty ?? true)
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
