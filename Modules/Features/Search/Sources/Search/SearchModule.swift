import Models
import Services
import SwiftUI
import YouTubeSDK

@MainActor
public final class SearchModule {
    private let viewModel: SearchViewModel
    private let spotifySessionCoordinator: SpotifySessionCoordinator?

    public init(
        youtube: YouTube,
        settings: PrefetchSettings,
        networkMonitor: NetworkPathMonitor,
        historyStore: Services.SearchHistoryStore,
        searchCacheHintStore: Services.SearchCacheHintStore,
        streamingProviderSettings: StreamingProviderSettings,
        centralMediaStore: CentralMediaStore?,
        metadataCache: any VideoMetadataCaching,
        searchCache: any SearchResultsCaching,
        spotifySessionCoordinator: SpotifySessionCoordinator? = nil
    ) {
        self.spotifySessionCoordinator = spotifySessionCoordinator
        self.viewModel = SearchViewModel(
            youtube: youtube,
            settings: settings,
            networkMonitor: networkMonitor,
            historyStore: historyStore,
            searchCacheHintStore: searchCacheHintStore,
            streamingProviderSettings: streamingProviderSettings,
            centralMediaStore: centralMediaStore,
            metadataCache: metadataCache,
            searchCache: searchCache
        )
    }

    public var view: some View {
        SearchView()
            .environment(viewModel)
            .environment(spotifySessionCoordinator)
    }

    public var searchText: Binding<String> {
        Binding(
            get: { self.viewModel.searchText },
            set: { self.viewModel.searchText = $0 }
        )
    }

    public func performSearch() {
        viewModel.performDebouncedSearch()
    }
}
