import Kingfisher
import Models
import Services
import SwiftData
import SwiftUI
import Utilities
import YouTubeSDK
import DesignSystem

#if canImport(SpotifySDK)
    import SpotifySDK
#endif

public struct SearchView: View {
    @Environment(AppServices.self) private var appServices
    @Environment(SearchServices.self) private var searchServices
    @Environment(PlaybackServices.self) private var playbackServices
    @Environment(LibraryServices.self) private var libraryServices
    @Environment(UserServices.self) private var userServices
    @Environment(\.modelContext) private var modelContext
    
    private var router: Router { appServices.router }
    private var searchViewModel: any SearchViewModelInterface { searchServices.searchViewModel }
    private var playerViewModel: any PlayerViewModelInterface { playbackServices.playerViewModel }
    private var centralMediaStore: CentralMediaStore { libraryServices.centralMediaStore }
    private var presentationController: PlayerPresentationController { appServices.playerPresentationController }
    #if canImport(SpotifySDK)
    private var spotifyCoordinator: SpotifySessionCoordinator { userServices.spotifySessionCoordinator }
    #endif

    @FocusState private var isSearchFocused: Bool
    @State private var isSearchPresentationActive: Bool = false
    @State private var showNonPlayableAlert: Bool = false
    @State private var nonPlayableMessage: String = ""
    @State private var selectedSpotifyArtist: SpotifySearchArtist?
    @State private var isImportingSpotifyPlaylistID: String?
    @State private var actionAlertMessage: String = ""
    @State private var showActionAlert: Bool = false

    public init() {}

    private var searchTextBinding: Binding<String> {
        Binding(
            get: { searchViewModel.searchText },
            set: { searchViewModel.searchText = $0 }
        )
    }

    public var body: some View {
        VStack(spacing: 0) {
            ZStack {
                switch searchViewModel.state {
                case .idle:
                    ContentUnavailableView("Search for something", systemImage: "magnifyingglass")

                case .loading:
                    ProgressView("Searching…")
                        .controlSize(.large)

                case .error(let message):
                    ContentUnavailableView(
                        "Error", systemImage: "exclamationmark.triangle", description: Text(message)
                    )

                case .success:
                    SearchResultsList(
                        searchViewModel: searchViewModel,
                        playerViewModel: playerViewModel,
                        isImportingSpotifyPlaylistID: $isImportingSpotifyPlaylistID,
                        selectedSpotifyArtist: $selectedSpotifyArtist,
                        showNonPlayableAlert: $showNonPlayableAlert,
                        nonPlayableMessage: $nonPlayableMessage,
                        onRowSelection: handleRowSelection
                    )
                }
            }
        }
        .onSubmit(of: .search) {
            isSearchFocused = false
            isSearchPresentationActive = false
        }
        .safeAreaPadding(.top, 20)
        .optionalSearchable(
            text: searchTextBinding,
            isFocused: $isSearchFocused,
            isPresented: $isSearchPresentationActive,
            suggestions: searchViewModel.suggestions,
            onSuggestionTap: { suggestion in
                searchViewModel.applySuggestion(suggestion)
            }
        )
        .sheet(item: $selectedSpotifyArtist) { artist in
            SpotifyArtistDetailSheet(
                artist: artist,
                onSearchSongs: { searchSongs(for: artist) }
            )
        }
        .alert(actionAlertMessage, isPresented: $showActionAlert) {
            Button("OK", role: .cancel) {}
        }
    }

    // MARK: - Actions

    private func handleRowSelection(_ item: FederatedSearchItem) {
        switch item.payload {
        case .youtubeMusic(let song):
            searchViewModel.recordSuccessfulPlayFromCurrentQuery()
            playerViewModel.load(song: song, preserveQueue: false)
            presentationController.expand()

        case .youtubeVideo(let video):
            searchViewModel.recordSuccessfulPlayFromCurrentQuery()
            playerViewModel.load(video: video, preserveQueue: false)
            presentationController.expand()

        case .spotify:
            Task {
                await playSpotifyTrack(item)
            }

        case .spotifyArtist(let artist):
            selectedSpotifyArtist = artist

        case .spotifyPlaylist(let playlist):
            Task {
                await handleSpotifyPlaylistTap(playlist)
            }
        }
    }

    private var playlistLibraryStore: PlaylistLibraryStore {
        PlaylistLibraryStore(context: modelContext)
    }

    #if canImport(SpotifySDK)
        private var spotifyPlaylistImportService: SpotifyPlaylistImportService? {
            guard let sdk = spotifyCoordinator.sdk else { return nil }
            return SpotifyPlaylistImportService(
                sdk: sdk,
                playlistStore: playlistLibraryStore,
                centralStore: centralMediaStore
            )
        }
    #endif

    private func playSpotifyTrack(_ item: FederatedSearchItem) async {
        do {
            guard let selectedPayload = try await searchViewModel.resolveExternalStream(for: item)
            else {
                throw FederatedSearchError.noPlayableStream(
                    "Unable to resolve a YouTube-backed stream for this Spotify track.")
            }

            guard
                let selectedTrack = makeExternalQueueTrack(
                    for: item,
                    preResolvedPayload: selectedPayload
                )
            else {
                throw FederatedSearchError.noPlayableStream(
                    "Unable to build the Spotify playback track.")
            }

            searchViewModel.recordSuccessfulPlayFromCurrentQuery()
            playerViewModel.load(external: selectedTrack, preserveQueue: false)
            presentationController.expand()
        } catch {
            nonPlayableMessage = error.localizedDescription
            showNonPlayableAlert = true
        }
    }

    private func handleSpotifyPlaylistTap(_ playlist: SpotifySearchPlaylist) async {
        #if canImport(SpotifySDK)
            if let existing = playlistLibraryStore.playlist(
                sourceProvider: .spotify, sourcePlaylistID: playlist.id)
            {
                router.navigate(to: "playlistDetail:\(existing.playlistID)")
                return
            }

            guard let importService = spotifyPlaylistImportService else {
                actionAlertMessage = "Spotify is not connected. Open Settings and sign in first."
                showActionAlert = true
                return
            }

            isImportingSpotifyPlaylistID = playlist.id
            defer { isImportingSpotifyPlaylistID = nil }

            do {
                let imported = try await importService.importPlaylist(id: playlist.id)
                router.navigate(to: "playlistDetail:\(imported.playlistID)")
            } catch {
                actionAlertMessage = error.localizedDescription
                showActionAlert = true
            }
        #else
            actionAlertMessage = "Spotify playlist import is unavailable on this target."
            showActionAlert = true
        #endif
    }

    private func searchSongs(for artist: SpotifySearchArtist) {
        searchViewModel.searchScope = .music
        searchViewModel.searchText = artist.name
        isSearchFocused = true
        isSearchPresentationActive = true
    }

    private func playlistID(for item: FederatedSearchItem) -> String? {
        guard case .spotifyPlaylist(let playlist) = item.payload else { return nil }
        return playlist.id
    }

    private func makeExternalQueueTracks(
        from items: [FederatedSearchItem],
        selectedItemID: String,
        selectedPayload: ExternalStreamPayload
    ) -> [Services.ExternalQueueTrack] {
        let tracks = items.compactMap { entry in
            makeExternalQueueTrack(
                for: entry,
                preResolvedPayload: entry.id == selectedItemID ? selectedPayload : nil
            )
        }

        if tracks.isEmpty {
            let fallbackTrack = Services.ExternalQueueTrack(
                mediaID: selectedPayload.mediaID,
                title: selectedPayload.title,
                artist: selectedPayload.artist,
                artworkURL: selectedPayload.artworkURL,
                service: selectedPayload.service,
                isExplicit: false,
                qualityLabelHint: selectedPayload.qualityLabel,
                codecLabelHint: selectedPayload.codecLabel,
                resolvePayload: {
                    selectedPayload
                }
            )
            return [fallbackTrack]
        }

        return tracks
    }

    private func makeExternalQueueTrack(
        for item: FederatedSearchItem,
        preResolvedPayload: ExternalStreamPayload? = nil
    ) -> Services.ExternalQueueTrack? {
        switch item.payload {
        case .spotify, .youtubeMusic, .youtubeVideo:
            break
        case .spotifyArtist, .spotifyPlaylist:
            return nil
        }

        let mediaID = preResolvedPayload?.mediaID ?? item.id

        return Services.ExternalQueueTrack(
            mediaID: mediaID,
            title: preResolvedPayload?.title ?? item.title,
            artist: preResolvedPayload?.artist ?? item.displayArtist,
            artworkURL: preResolvedPayload?.artworkURL ?? item.artworkURL,
            service: preResolvedPayload?.service ?? item.service,
            isExplicit: item.isExplicit,
            qualityLabelHint: preResolvedPayload?.qualityLabel ?? item.audioQualityLabel,
            codecLabelHint: preResolvedPayload?.codecLabel ?? item.audioCodecLabel,
            resolvePayload: {
                if let preResolvedPayload {
                    return preResolvedPayload
                }

                guard let payload = try await searchViewModel.resolveExternalStream(for: item)
                else {
                    throw FederatedSearchError.noPlayableStream(
                        "Unable to resolve a playable stream for this track.")
                }
                return payload
            }
        )
    }
}

// MARK: - Search Results List

private struct SearchResultsList: View {
    let searchViewModel: any SearchViewModelInterface
    let playerViewModel: any PlayerViewModelInterface
    @Binding var isImportingSpotifyPlaylistID: String?
    @Binding var selectedSpotifyArtist: SpotifySearchArtist?
    @Binding var showNonPlayableAlert: Bool
    @Binding var nonPlayableMessage: String
    let onRowSelection: (FederatedSearchItem) -> Void

    var body: some View {
        let hasSpotifyTracks = !searchViewModel.spotifyTrackResults.isEmpty
        let hasSpotifyArtists = !searchViewModel.spotifyArtistResults.isEmpty
        let hasSpotifyPlaylists = !searchViewModel.spotifyPlaylistResults.isEmpty
        let hasSpotify = hasSpotifyTracks || hasSpotifyArtists || hasSpotifyPlaylists
        let hasHiddenTopResults = !searchViewModel.unifiedTopResults.isEmpty

        List {
            // MARK: Spotify Tracks
            if hasSpotifyTracks {
                Section {
                    ForEach(searchViewModel.spotifyTrackResults) { item in
                        Button {
                            onRowSelection(item)
                        } label: {
                            SearchTrackRow(
                                item: item, fallback: searchViewModel.hiddenFallbackMap[item.id]
                            )
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    SearchSectionHeader(title: "Tracks", subtitle: "From Spotify")
                }
            }

            // MARK: Spotify Artists
            if hasSpotifyArtists {
                Section {
                    ForEach(searchViewModel.spotifyArtistResults) { item in
                        Button {
                            onRowSelection(item)
                        } label: {
                            SearchArtistRow(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    SearchSectionHeader(title: "Artists", subtitle: "From Spotify")
                }
            }

            // MARK: Spotify Playlists
            if hasSpotifyPlaylists {
                Section {
                    ForEach(searchViewModel.spotifyPlaylistResults) { item in
                        let playlistID = playlistID(for: item)
                        Button {
                            onRowSelection(item)
                        } label: {
                            SearchPlaylistRow(
                                item: item,
                                isImporting: isImportingSpotifyPlaylistID == playlistID)
                        }
                        .buttonStyle(.plain)
                        .disabled(isImportingSpotifyPlaylistID == playlistID)
                    }
                } header: {
                    SearchSectionHeader(title: "Playlists", subtitle: "From Spotify")
                }
            }

            // MARK: Additional Results
            if hasHiddenTopResults {
                Section {
                    if searchViewModel.unifiedTopResults.isEmpty {
                        Text("No results")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(searchViewModel.unifiedTopResults) { item in
                            Button {
                                onRowSelection(item)
                            } label: {
                                SearchFederatedRow(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    SearchSectionHeader(title: "Top Results", subtitle: "From YouTube")
                }
            }

            // MARK: You Might Like
            if !searchViewModel.youMightLikeResults.isEmpty {
                Section {
                    ForEach(searchViewModel.youMightLikeResults) { item in
                        Button {
                            onRowSelection(item)
                        } label: {
                            SearchFederatedRow(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("You Might Like")
                        if let anchorTitle =
                            (searchViewModel.spotifyTrackResults.first
                            ?? searchViewModel.unifiedTopResults.first)?.title
                        {
                            Text("Similar to \"\(anchorTitle)\"")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // MARK: Empty Spotify state
            if hasSpotify == false && hasHiddenTopResults == false {
                Section {
                    Label(
                        "Connect Spotify in Settings for richer results.",
                        systemImage: "person.crop.circle.badge.plus"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .contentMargins(.bottom, 140)
        .listStyle(.plain)
        .alert(nonPlayableMessage, isPresented: $showNonPlayableAlert) {
            Button("OK", role: .cancel) {}
        }
    }

    private func playlistID(for item: FederatedSearchItem) -> String? {
        guard case .spotifyPlaylist(let playlist) = item.payload else { return nil }
        return playlist.id
    }
}
