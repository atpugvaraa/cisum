import Foundation
import Services

public final class CoreDomain {
    public let streamingProviderSettings: StreamingProviderSettings
    public let prefetchSettings: PrefetchSettings
    public let networkMonitor: NetworkPathMonitor

    public init(
        streamingProviderSettings: StreamingProviderSettings,
        prefetchSettings: PrefetchSettings,
        networkMonitor: NetworkPathMonitor
    ) {
        self.streamingProviderSettings = streamingProviderSettings
        self.prefetchSettings = prefetchSettings
        self.networkMonitor = networkMonitor
    }
}


extension CoreDomain {
    public var interface: CoreInterface {
        CoreInterface(
            streamingProviderSettings: streamingProviderSettings,
            prefetchSettings: prefetchSettings,
            networkMonitor: networkMonitor
        )
    }
}
