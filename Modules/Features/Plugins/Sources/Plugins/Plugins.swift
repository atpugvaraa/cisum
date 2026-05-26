import Foundation
import ProviderSDK
import Services
import YouTubeSDK

public enum Plugins {
	public static func makeProviderSDK() -> ProviderSDK {
		ProviderSDK()
	}

	public static func makePlaybackProviders(
		providerSDK: ProviderSDK,
		youtube: YouTube,
		mediaCacheStore: MediaCacheStore,
		metadataCache: any VideoMetadataCaching,
		includeProviderSDK: Bool = true,
		includeYouTubeFallback: Bool = true
	) -> [any StreamResolutionProvider] {
		var providers: [any StreamResolutionProvider] = []

		if includeProviderSDK {
			providers.append(ProviderSDKStreamResolver(providerSDK: providerSDK))
		}

		if includeYouTubeFallback || providers.isEmpty {
			providers.append(
				YouTubeStreamResolver(
					youtube: youtube,
					mediaCacheStore: mediaCacheStore,
					metadataCache: metadataCache
				)
			)
		}

		return providers
	}

	@MainActor
	public static func configurePlaybackURLResolver(
		providerSDK: ProviderSDK? = nil,
		youtube: YouTube,
		mediaCacheStore: MediaCacheStore,
		metadataCache: any VideoMetadataCaching,
		includeProviderSDK: Bool = true,
		includeYouTubeFallback: Bool = true
	) {
		let providerSDK = providerSDK ?? ProviderSDK()
		PlaybackURLResolver.configureShared(
			providers: makePlaybackProviders(
				providerSDK: providerSDK,
				youtube: youtube,
				mediaCacheStore: mediaCacheStore,
				metadataCache: metadataCache,
				includeProviderSDK: includeProviderSDK,
				includeYouTubeFallback: includeYouTubeFallback
			)
		)
	}
}
