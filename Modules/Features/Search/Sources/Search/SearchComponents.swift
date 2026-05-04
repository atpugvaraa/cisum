import Kingfisher
import Models
import SwiftUI
import Utilities
import YouTubeSDK

// MARK: - Spotify Track Row

public struct SearchTrackRow: View {
    let item: FederatedSearchItem
    let fallback: FederatedSearchItem?

    public init(item: FederatedSearchItem, fallback: FederatedSearchItem?) {
        self.item = item
        self.fallback = fallback
    }

    public var body: some View {
        HStack(spacing: 12) {
            KFImage(item.artworkURL)
                .downsampling(size: CGSize(width: 100, height: 100))
                .placeholder { Color.gray.opacity(0.3) }
                .resizable()
                .scaledToFill()
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(1)

                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    // Spotify badge
                    SearchBadge(
                        title: "Spotify",
                        tint: Color(red: 0.11, green: 0.73, blue: 0.33).opacity(0.15),
                        textColor: Color(red: 0.11, green: 0.73, blue: 0.33))

                    if item.isExplicit {
                        SearchBadge(title: "Explicit", tint: .red.opacity(0.16), textColor: .red)
                    }

                    // Show quality of the matched hidden provider if found
                    if let quality = fallback?.audioQualityLabel {
                        SearchBadge(title: quality, tint: .blue.opacity(0.14), textColor: .blue)
                    }
                }
                .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let duration = item.displayDuration {
                    Text(duration)
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                // Stream readiness indicator
                if fallback != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.green.opacity(0.8))
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption2)
                        .foregroundStyle(.secondary.opacity(0.5))
                }
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title) by \(item.subtitle) on Spotify")
        .accessibilityHint(fallback != nil ? "Double tap to play" : "Resolving stream")

    }
}

// MARK: - Artist Row

public struct SearchArtistRow: View {
    let item: FederatedSearchItem

    public init(item: FederatedSearchItem) {
        self.item = item
    }

    public var body: some View {
        HStack(spacing: 12) {
            KFImage(item.artworkURL)
                .downsampling(size: CGSize(width: 80, height: 80))
                .placeholder { Color.gray.opacity(0.3) }
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(1)

                Text("Artist")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Artist: \(item.title)")
        .accessibilityHint("Double tap to view details")

    }
}

// MARK: - Playlist Row

public struct SearchPlaylistRow: View {
    let item: FederatedSearchItem
    let isImporting: Bool

    public init(item: FederatedSearchItem, isImporting: Bool) {
        self.item = item
        self.isImporting = isImporting
    }

    public var body: some View {
        HStack(spacing: 12) {
            KFImage(item.artworkURL)
                .downsampling(size: CGSize(width: 100, height: 100))
                .placeholder {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.ultraThinMaterial)
                }
                .resizable()
                .scaledToFill()
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(1)

                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isImporting {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Playlist: \(item.title) by \(item.subtitle)")
        .accessibilityHint(isImporting ? "Importing playlist" : "Double tap to open")

    }
}

// MARK: - Federated Row

public struct SearchFederatedRow: View {
    let item: FederatedSearchItem

    public init(item: FederatedSearchItem) {
        self.item = item
    }

    public var body: some View {
        HStack(spacing: 12) {
            KFImage(item.artworkURL)
                .downsampling(size: CGSize(width: 100, height: 100))
                .placeholder {
                    Color.gray.opacity(0.3)
                }
                .resizable()
                .scaledToFill()
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(1)

                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if item.isExplicit || item.audioQualityLabel != nil || item.audioCodecLabel != nil {
                    SearchMetadataBadges(item: item)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let duration = item.displayDuration {
                    Text(duration)
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                if !item.isPlayable {
                    Text("Metadata")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title) by \(item.subtitle) from \(item.service.rawValue)")
        .accessibilityHint(item.isPlayable ? "Double tap to play" : "Metadata only")

    }
}

// MARK: - Supporting Components

public struct SearchBadge: View {
    let title: String
    let tint: Color
    let textColor: Color

    public init(title: String, tint: Color, textColor: Color) {
        self.title = title
        self.tint = tint
        self.textColor = textColor
    }

    public var body: some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(tint, in: Capsule())
            .foregroundStyle(textColor)
            .accessibilityLabel(title)

    }
}

public struct SearchMetadataBadges: View {
    let item: FederatedSearchItem

    public init(item: FederatedSearchItem) {
        self.item = item
    }

    public var body: some View {
        HStack(spacing: 6) {
            SearchBadge(
                title: item.service.rawValue, tint: .secondary.opacity(0.12), textColor: .secondary)

            if item.isExplicit {
                SearchBadge(title: "Explicit", tint: .red.opacity(0.16), textColor: .red)
            }

            if let quality = item.audioQualityLabel {
                SearchBadge(title: quality, tint: .blue.opacity(0.14), textColor: .blue)
            }

            if let codec = item.audioCodecLabel {
                SearchBadge(title: codec, tint: .secondary.opacity(0.16), textColor: .secondary)
            }
        }
        .lineLimit(1)
        .truncationMode(.tail)

    }
}

public struct SearchSectionHeader: View {
    let title: String
    let subtitle: String?

    public init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

public struct SpotifyArtistDetailSheet: View {
    let artist: SpotifySearchArtist
    let onSearchSongs: () -> Void
    @Environment(\.dismiss) private var dismiss

    public init(artist: SpotifySearchArtist, onSearchSongs: @escaping () -> Void) {
        self.artist = artist
        self.onSearchSongs = onSearchSongs
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let url = artist.artworkURL {
                        KFImage(url)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 200, height: 200)
                            .clipShape(Circle())
                            .shadow(radius: 10)
                    } else {
                        Circle()
                            .fill(.secondary.opacity(0.2))
                            .frame(width: 200, height: 200)
                            .overlay {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 80))
                                    .foregroundStyle(.secondary)
                            }
                    }

                    VStack(spacing: 8) {
                        Text(artist.name)
                            .font(.title.bold())

                        if !artist.genres.isEmpty {
                            Text(artist.genres.joined(separator: ", "))
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        onSearchSongs()
                        dismiss()
                    } label: {
                        Label("Search Songs", systemImage: "magnifyingglass")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)

                    Text("Artist details and top tracks would go here.")
                        .foregroundStyle(.secondary)
                        .padding()
                }
                .padding()
            }
            .navigationTitle("Artist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
