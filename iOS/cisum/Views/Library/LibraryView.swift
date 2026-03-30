//
//  LibraryView.swift
//  cisum
//
//  Created by Aarav Gupta on 15/03/26.
//

import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.router) private var router
    @Query(sort: \Playlist.updatedAt, order: .reverse) private var playlists: [Playlist]
    @State private var isPresentingImportSheet: Bool = false

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

                playlistSection

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
        .sheet(isPresented: $isPresentingImportSheet) {
            YouTubePlaylistImportSheet { importedPlaylistID in
                router.navigate(to: .playlistDetail(importedPlaylistID))
            }
        }
        .enableInjection()
    }

    private var playlistSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Playlists", systemImage: "music.note.list")
                    .font(.headline)

                Spacer()

                Button {
                    isPresentingImportSheet = true
                } label: {
                    Label("Add", systemImage: "plus")
                        .labelStyle(.iconOnly)
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Import Playlist")

                Text("\(playlists.count)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            if playlists.isEmpty {
                LibraryPlaceholderCard(
                    title: "No Imported Playlists",
                    subtitle: "Imports will appear here as they are completed.",
                    systemImage: "tray"
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(playlists) { playlist in
                        Button {
                            router.navigate(to: .playlistDetail(playlist.playlistID))
                        } label: {
                            PlaylistRow(playlist: playlist)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
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

private struct PlaylistRow: View {
    let playlist: Playlist

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.thinMaterial)

                Image(systemName: "music.note.list")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(playlist.title)
                    .font(.headline)
                    .lineLimit(1)

                Text("\(playlist.itemCount) tracks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
}

#Preview {
    LibraryView()
}
