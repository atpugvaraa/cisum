//
//  SearchView.swift
//  cisum
//
//  Created by Aarav Gupta on 04/12/25.
//

import SwiftUI
import YouTubeSDK

struct SearchView: View {
    @Environment(SearchViewModel.self) private var searchViewModel
    @Environment(PlayerViewModel.self) private var playerViewModel
    
    // UI State
    @State private var showPlayer = false
    @FocusState private var isSearchFocused: Bool
    @State private var showNonPlayableAlert: Bool = false
    @State private var nonPlayableMessage: String = ""

    #if DEBUG
    @ObserveInjection var forceRedraw
    #endif

    var body: some View {
        searchContent
            .sheet(isPresented: $showPlayer) {
                NowPlayingView()
                    .environment(playerViewModel)
            }
            .optionalSearchable(
                text: Bindable(searchViewModel).searchText,
                scope: Bindable(searchViewModel).searchScope,
                suggestions: searchViewModel.suggestions,
                onSuggestionTap: { suggestion in
                    searchViewModel.applySuggestion(suggestion)
                }
            )
        .enableInjection()
    }

    private var searchContent: some View {
        VStack(spacing: 0) {
            if shouldShowInlineSuggestions && !searchViewModel.suggestions.isEmpty {
                SuggestionsList()
            }
            
            ZStack {
                switch searchViewModel.state {
                case .idle:
                    ContentUnavailableView("Search for something", systemImage: "magnifyingglass")
                    
                case .loading:
                    ProgressView("Searching YouTube...")
                        .controlSize(.large)
                    
                case .error(let message):
                    ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(message))
                    
                case .success:
                    ResultsList()
                }
            }
        }
        .enableInjection()
        .onSubmit(of: .search) {
            isSearchFocused = false
        }
    }

    private var shouldShowInlineSuggestions: Bool {
        if #available(iOS 26.0, *) {
            return false
        } else {
            return true
        }
    }
    
    // MARK: - Subviews
    @ViewBuilder
    private func ResultsList() -> some View {
        List {
            if searchViewModel.searchScope == .music {
                // Music Results
                ForEach(searchViewModel.musicResults) { song in
                    Button {
                        playMusic(song)
                    } label: {
                        HStack(spacing: 12) {
                            // Thumbnail
                            AsyncImage(url: song.thumbnailURL) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Color.gray.opacity(0.3)
                            }
                            .frame(width: 50, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(song.title)
                                    .font(.headline)
                                    .lineLimit(1)
                                
                                Text("\(song.artistsDisplay) • \(song.album ?? "Single")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            // Duration
                            if let duration = song.duration {
                                Text(formatDuration(duration))
                                    .font(.caption2)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .listRowSeparator(.hidden)
                    .onAppear {
                        searchViewModel.prefetchIfNeeded(id: song.videoId)
                    }
                }
            } else {
                ForEach(searchViewModel.videoResults) { item in
                    switch item {
                    case .video(let video):
                        Button {
                            playVideo(video)
                        } label: {
                            HStack(spacing: 12) {
                                AsyncImage(url: normalizedThumbnailURL(from: video.thumbnailURL)) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Color.gray.opacity(0.3)
                                }
                                .frame(width: 80, height: 45)
                                .clipShape(RoundedRectangle(cornerRadius: 4))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(video.title)
                                        .font(.subheadline)
                                        .lineLimit(2)

                                    Text(video.author)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onAppear {
                            searchViewModel.loadMoreVideosIfNeeded(for: item)
                            searchViewModel.prefetchIfNeeded(id: video.id)
                        }
                        .id(item.id)

                    case .channel(let channel):
                        Button {
                            nonPlayableMessage = "Channels are not playable yet. Open channel: \(channel.title)"
                            showNonPlayableAlert = true
                        } label: {
                            HStack(spacing: 12) {
                                AsyncImage(url: normalizedThumbnailURL(from: channel.thumbnailURL)) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Color.gray.opacity(0.3)
                                }
                                .frame(width: 50, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 6))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(channel.title)
                                        .font(.headline)
                                        .lineLimit(1)

                                    Text(channel.subscriberCount ?? "")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onAppear {
                            searchViewModel.loadMoreVideosIfNeeded(for: item)
                        }
                        .id(item.id)

                    case .playlist(let playlist):
                        Button {
                            nonPlayableMessage = "Playlists are not playable yet. Open playlist: \(playlist.title)"
                            showNonPlayableAlert = true
                        } label: {
                            HStack(spacing: 12) {
                                if let url = normalizedThumbnailURL(from: playlist.thumbnailURL) {
                                    AsyncImage(url: url) { image in
                                        image.resizable().scaledToFill()
                                    } placeholder: {
                                        Color.gray.opacity(0.3)
                                    }
                                    .frame(width: 50, height: 50)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                } else {
                                    Color.gray.frame(width: 50, height: 50).clipShape(RoundedRectangle(cornerRadius: 6))
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(playlist.title)
                                        .font(.headline)
                                        .lineLimit(1)

                                    Text(playlist.videoCount ?? "")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .id(item.id)
                    }
                }

                if searchViewModel.isVideoPaginationLoading {
                    HStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading more…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
                    .listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.plain)
        .alert(nonPlayableMessage, isPresented: $showNonPlayableAlert) {
            Button("OK", role: .cancel) { }
        }
    }

    @ViewBuilder
    private func SuggestionsList() -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(searchViewModel.suggestions, id: \.self) { suggestion in
                    Button {
                        searchViewModel.applySuggestion(suggestion)
                        isSearchFocused = false
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkle.magnifyingglass")
                                .font(.caption)
                            Text(suggestion)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.15), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 4)
    }
    
    // MARK: - Actions
    private func playMusic(_ song: YouTubeMusicSong) {
        print("Loading: \(song.title)")
        searchViewModel.recordSuccessfulPlayFromCurrentQuery()
        playerViewModel.load(song: song)
        showPlayer = true
    }
    
    private func playVideo(_ video: YouTubeVideo) {
        print("Selected Video: \(video.title)")
        // Call your PlayerViewModel here
        searchViewModel.recordSuccessfulPlayFromCurrentQuery()
        playerViewModel.load(video: video)
        showPlayer = true
    }
    
    // Helper for duration (e.g., 200 -> "3:20")
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let min = Int(seconds) / 60
        let sec = Int(seconds) % 60
        return String(format: "%d:%02d", min, sec)
    }

    private func normalizedThumbnailURL(from string: String?) -> URL? {
        guard var candidate = string?.trimmingCharacters(in: .whitespacesAndNewlines), !candidate.isEmpty else { return nil }
        if candidate.hasPrefix("//") {
            candidate = "https:" + candidate
        } else if !candidate.hasPrefix("http://") && !candidate.hasPrefix("https://") {
            candidate = "https://" + candidate
        }
        return URL(string: candidate)
    }

    private func normalizedThumbnailURL(from url: URL?) -> URL? {
        guard let url = url else { return nil }
        if let scheme = url.scheme, !scheme.isEmpty {
            return url
        }
        return normalizedThumbnailURL(from: url.absoluteString)
    }
}

#Preview {
    SearchView()
        .environment(PlayerViewModel())
        .environment(SearchViewModel())
}

extension View {
    @ViewBuilder
    func optionalSearchable(
        text: Binding<String>,
        scope: Binding<SearchViewModel.SearchScope>,
        suggestions: [String],
        onSuggestionTap: @escaping (String) -> Void
    ) -> some View {
        if #available(iOS 26.0, *) {
            self
                .searchable(
                    text: text,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: Text("Search")
                )
                .searchSuggestions {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button(suggestion) {
                            onSuggestionTap(suggestion)
                        }
                    }
                }
                .searchScopes(scope) {
                    Text("Music").tag(SearchViewModel.SearchScope.music)
                    Text("YouTube").tag(SearchViewModel.SearchScope.video)
                }
                .searchPresentationToolbarBehavior(.avoidHidingContent)
                .searchToolbarBehavior(.minimize)
        } else {
            self.searchScopes(scope) {
                Text("Music").tag(SearchViewModel.SearchScope.music)
                Text("YouTube").tag(SearchViewModel.SearchScope.video)
            }
        }
    }
}
