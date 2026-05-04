import Foundation
import Search
import Services

public final class SearchDomain {
    internal let searchViewModel: SearchViewModel
    internal let historyStore: Services.SearchHistoryStore
    internal let searchCacheHintStore: Services.SearchCacheHintStore
    internal let searchCache: any SearchResultsCaching
    internal let suggestionRanker: SuggestionRanker.Type

    public init(
        searchViewModel: SearchViewModel,
        historyStore: Services.SearchHistoryStore,
        searchCacheHintStore: Services.SearchCacheHintStore,
        searchCache: any SearchResultsCaching,
        suggestionRanker: SuggestionRanker.Type
    ) {
        self.searchViewModel = searchViewModel
        self.historyStore = historyStore
        self.searchCacheHintStore = searchCacheHintStore
        self.searchCache = searchCache
        self.suggestionRanker = suggestionRanker
    }

    public func interface(networkMonitor: NetworkPathMonitor, prefetchSettings: PrefetchSettings) -> SearchInterface {
        SearchInterface(
            historyStore: historyStore,
            searchCacheHintStore: searchCacheHintStore,
            searchCache: searchCache,
            suggestionRanker: suggestionRanker,
            networkMonitor: networkMonitor,
            prefetchSettings: prefetchSettings,
            searchViewModel: searchViewModel
        )
    }
}
