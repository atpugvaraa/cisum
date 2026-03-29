//
//  DiscoverView.swift
//  cisum
//
//  Created by Aarav Gupta on 15/03/26.
//

import SwiftUI
import YouTubeSDK

struct DiscoverView: View {
    @Environment(\.youtube) private var youtube

    @State private var sections: [DiscoverSection] = []
    @State private var isLoading: Bool = false
    @State private var didLoadInitialSections: Bool = false
    @State private var errorMessage: String?

    #if DEBUG
    @ObserveInjection var forceRedraw
    #endif

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                header

                if isLoading && sections.isEmpty {
                    ProgressView("Loading Charts...")
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                if let errorMessage, sections.isEmpty {
                    ContentUnavailableView(
                        "Unable to Load Discover",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text(errorMessage)
                    )

                    Button("Retry") {
                        Task {
                            await loadDiscoverSections(force: true)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }

                ForEach(sections) { section in
                    DiscoverSectionView(section: section)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 120)
        }
        .contentMargins(.top, 140)
        .task {
            if !didLoadInitialSections {
                await loadDiscoverSections()
            }
        }
        .refreshable {
            await loadDiscoverSections(force: true)
        }
            .enableInjection()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Discover")
                .font(.largeTitle.weight(.semibold))
            Text("Charts from YouTube Music and YouTube")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @MainActor
    private func loadDiscoverSections(force: Bool = false) async {
        if isLoading { return }
        if didLoadInitialSections && !force { return }

        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            didLoadInitialSections = true
        }

        let countryCode = resolvedMusicRegionCode()

        async let songsTask = youtube.charts.getTopSongs(country: countryCode)
        async let videosTask = youtube.charts.getTopVideos(country: countryCode)
        async let artistsTask = youtube.charts.getTopArtists(country: countryCode)
        async let trendingTask = youtube.charts.getTrending(country: countryCode)

        var loadedSections: [DiscoverSection] = []
        var lastError: Error?

        do {
            let songs = try await songsTask
            if !songs.isEmpty {
                loadedSections.append(.init(id: "songs", title: "Top Songs", subtitle: "YouTube Music", items: Array(songs.prefix(10))))
            }
        } catch {
            lastError = error
        }

        do {
            let videos = try await videosTask
            if !videos.isEmpty {
                loadedSections.append(.init(id: "videos", title: "Top Videos", subtitle: "YouTube", items: Array(videos.prefix(10))))
            }
        } catch {
            lastError = error
        }

        do {
            let artists = try await artistsTask
            if !artists.isEmpty {
                loadedSections.append(.init(id: "artists", title: "Top Artists", subtitle: "YouTube Music", items: Array(artists.prefix(10))))
            }
        } catch {
            lastError = error
        }

        do {
            let trending = try await trendingTask
            if !trending.isEmpty {
                loadedSections.append(.init(id: "trending", title: "Trending", subtitle: "YouTube", items: Array(trending.prefix(10))))
            }
        } catch {
            lastError = error
        }

        sections = loadedSections
        if loadedSections.isEmpty {
            errorMessage = lastError?.localizedDescription ?? "No chart data was returned."
        }
    }
}

private struct DiscoverSection: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let items: [YouTubeChartItem]
}

private struct DiscoverSectionView: View {
    let section: DiscoverSection

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(section.title)
                    .font(.title3.weight(.semibold))
                Text(section.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LazyVStack(spacing: 8) {
                ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                    DiscoverChartRow(rank: index + 1, item: item)
                }
            }
        }
    }
}

private struct DiscoverChartRow: View {
    let rank: Int
    let item: YouTubeChartItem

    var body: some View {
        HStack(spacing: 12) {
            Text("#\(rank)")
                .font(.caption.weight(.semibold))
                .frame(width: 34)
                .foregroundStyle(.secondary)

            if let artworkURL = item.thumbnailURL {
                AsyncImage(url: artworkURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.gray.opacity(0.2))
                }
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
}

#Preview {
    DiscoverView()
}
