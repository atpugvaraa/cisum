import SwiftUI
import SwiftData

struct PlaylistDetailView: View {
    let playlistID: String

    @Query private var playlists: [Playlist]
    @Query private var items: [PlaylistItem]

    #if DEBUG
    @ObserveInjection var forceRedraw
    #endif

    init(playlistID: String) {
        self.playlistID = playlistID
        _playlists = Query(
            filter: #Predicate<Playlist> { $0.playlistID == playlistID },
            sort: \Playlist.updatedAt,
            order: .reverse
        )
        _items = Query(
            filter: #Predicate<PlaylistItem> { $0.playlistID == playlistID },
            sort: \PlaylistItem.sortIndex,
            order: .forward
        )
    }

    private var playlist: Playlist? {
        playlists.first
    }

    var body: some View {
        List {
            if let playlist {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(playlist.title)
                            .font(.title3.weight(.semibold))
                        if let subtitle = playlist.subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Text("\(items.count) tracks")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }

            if items.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No Tracks Yet",
                        systemImage: "music.note",
                        description: Text("This playlist is ready, but no tracks have been imported yet.")
                    )
                }
            } else {
                Section("Tracks") {
                    ForEach(items) { item in
                        PlaylistTrackRow(item: item)
                    }
                }
            }
        }
        .navigationTitle(playlist?.title ?? "Playlist")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .enableInjection()
    }
}

private struct PlaylistTrackRow: View {
    let item: PlaylistItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(item.sortIndex + 1)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.body)
                    .lineLimit(1)

                if let artistName = item.artistName, !artistName.isEmpty {
                    Text(artistName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if item.importStatus == .uncertain {
                Text("Review")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(.orange.opacity(0.12), in: Capsule())
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        PlaylistDetailView(playlistID: "preview")
    }
}