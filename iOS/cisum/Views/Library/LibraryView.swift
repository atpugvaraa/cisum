//
//  LibraryView.swift
//  cisum
//
//  Created by Aarav Gupta on 15/03/26.
//

import SwiftUI

struct LibraryView: View {
    #if DEBUG
    @ObserveInjection var forceRedraw
    #endif

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Library")
                        .font(.largeTitle.weight(.semibold))

                    Text("Placeholder library screen. Full data-backed library is planned for a later pass.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                LibraryPlaceholderCard(
                    title: "Liked Songs",
                    subtitle: "Coming soon",
                    systemImage: "heart.fill"
                )

                LibraryPlaceholderCard(
                    title: "Recent Plays",
                    subtitle: "Coming soon",
                    systemImage: "clock.fill"
                )

                LibraryPlaceholderCard(
                    title: "Playlists",
                    subtitle: "Coming soon",
                    systemImage: "music.note.list"
                )

                LibraryPlaceholderCard(
                    title: "Downloaded",
                    subtitle: "Coming soon",
                    systemImage: "arrow.down.circle.fill"
                )
            }
            .padding()
            .padding(.bottom, 120)
        }
        .contentMargins(.top, 140)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .enableInjection()
    }
}

private struct LibraryPlaceholderCard: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
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
}

#Preview {
    LibraryView()
}
