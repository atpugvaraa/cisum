//
//  ProfileView.swift
//  cisum
//
//  Created by Aarav Gupta on 15/03/26.
//

import SwiftUI
import YouTubeSDK

struct ProfileView: View {
    @Environment(\.youtube) private var youtube

    @State private var showLoginSheet: Bool = false
    @State private var hasStoredSession: Bool = false

    #if DEBUG
    @ObserveInjection var forceRedraw
    #endif

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                profileHeader

                profileStatusCard

                Button {
                    showLoginSheet = true
                } label: {
                    Label(hasStoredSession ? "Reconnect Google Account" : "Login with Google", systemImage: "person.badge.key")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                if hasStoredSession {
                    Button(role: .destructive) {
                        YouTubeOAuthClient.logout()
                        youtube.cookies = nil
                        refreshSessionState()
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                Text("This profile screen is intentionally lightweight for now and will be expanded in a later pass.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .safeAreaPadding(.top)
        .sheet(isPresented: $showLoginSheet) {
            GoogleLoginView { cookies in
                Task { @MainActor in
                    YouTubeOAuthClient.saveCookies(cookies)
                    youtube.cookies = cookies
                    refreshSessionState()
                    showLoginSheet = false
                }
            }
        }
        .onAppear {
            refreshSessionState()
        }
        .enableInjection()
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
            Image(systemName: hasStoredSession ? "checkmark.seal.fill" : "person.crop.circle.badge.exclamationmark")
                .font(.title2)
                .foregroundStyle(hasStoredSession ? .green : .orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(hasStoredSession ? "Signed In" : "Not Signed In")
                    .font(.headline)
                Text(hasStoredSession ? "Active cookie session detected." : "Sign in to improve search relevance.")
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
        let cookies = YouTubeOAuthClient.loadCookies()
        hasStoredSession = !(cookies?.isEmpty ?? true)
    }
}

#Preview {
    ProfileView()
}
