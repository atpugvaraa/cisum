import Foundation
import Observation
import PostHog

@Observable
@MainActor
public final class AnalyticsService {
    private let projectToken: String = "phc_BiEiUXcrGHDqDSMuaLQrq2MhcJFyTp97WEcF5baG2A9V"
    private let host: String = "https://eu.i.posthog.com"
    
    public private(set) var isInitialized: Bool = false
    
    public init() {
        setupPostHog()
    }
    
    private func setupPostHog() {
        let config = PostHogConfig(projectToken: projectToken, host: host)
        PostHogSDK.shared.setup(config)
        isInitialized = true
    }
    
    /// Identify the current user
    /// This must be called after successful authentication to link events to the user
    public func identify(userId: String, properties: [String: Any]? = nil) {
        var props = properties ?? [:]
        PostHogSDK.shared.identify(userId, userProperties: props)
    }
    
    /// Capture a custom event
    public func captureEvent(_ eventName: String, properties: [String: Any]? = nil) {
        PostHogSDK.shared.capture(eventName, properties: properties ?? [:])
    }
    
    /// Clear current user identity (for sign-out)
    public func reset() {
        PostHogSDK.shared.reset()
    }
}
