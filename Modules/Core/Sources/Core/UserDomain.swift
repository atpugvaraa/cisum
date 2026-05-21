import Foundation
import Services

public final class UserDomain {
    internal let spotifySessionCoordinator: SpotifySessionCoordinator
    internal let authService: AuthService
    internal let supabaseService: SupabaseService
    internal let analyticsService: AnalyticsService

    public init(
        spotifySessionCoordinator: SpotifySessionCoordinator,
        authService: AuthService,
        supabaseService: SupabaseService,
        analyticsService: AnalyticsService
    ) {
        self.spotifySessionCoordinator = spotifySessionCoordinator
        self.authService = authService
        self.supabaseService = supabaseService
        self.analyticsService = analyticsService
    }

    public var interface: UserInterface {
        UserInterface(
            spotifySessionCoordinator: spotifySessionCoordinator,
            authService: authService,
            supabaseService: supabaseService,
            analyticsService: analyticsService
        )
    }
}
