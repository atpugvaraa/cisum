import Foundation
import Observation

public enum OverlaySearchScope: Hashable, Identifiable, Sendable {
    case global
    case playlist(id: String, title: String)

    public var id: String {
        switch self {
        case .global:
            return "global"
        case .playlist(let id, _):
            return "playlist-\(id)"
        }
    }

    public var title: String {
        switch self {
        case .global:
            return "Global"
        case .playlist(_, let title):
            return title
        }
    }

    public var symbolName: String {
        switch self {
        case .global:
            return "globe"
        case .playlist:
            return "music.note.list"
        }
    }

    public var prompt: String {
        switch self {
        case .global:
            return "Search songs, artists, and videos"
        case .playlist(_, let title):
            return "Search in \(title)"
        }
    }

    public var isGlobal: Bool {
        if case .global = self {
            return true
        }
        return false
    }
}

public struct SearchOverlayContext: Equatable, Sendable {
    public var availableScopes: [OverlaySearchScope]
    public var preferredScope: OverlaySearchScope

    public static let global = SearchOverlayContext(
        availableScopes: [.global],
        preferredScope: .global
    )

    public static func playlist(playlistID: String, playlistTitle: String) -> SearchOverlayContext {
        let playlistScope = OverlaySearchScope.playlist(id: playlistID, title: playlistTitle)
        return SearchOverlayContext(
            availableScopes: [playlistScope, .global],
            preferredScope: playlistScope
        )
    }
}

public struct SearchOverlayContextPreferenceKey: PreferenceKey {
    public static let defaultValue: SearchOverlayContext = .global

    public static func reduce(
        value: inout SearchOverlayContext, nextValue: () -> SearchOverlayContext
    ) {
        value = nextValue()
    }
}

import SwiftUI

extension View {
    public func searchOverlayContext(_ context: SearchOverlayContext) -> some View {
        preference(key: SearchOverlayContextPreferenceKey.self, value: context)
    }
}

@Observable
@MainActor
public final class SearchOverlayController {
    public var query: String = ""
    public var context: SearchOverlayContext = .global
    public var selectedScope: OverlaySearchScope = .global
    public var focusRequestID: Int = 0

    public init() {}

    private var globalQuery: String = ""
    private var playlistQueries: [String: String] = [:]

    public var canSwitchToGlobalFromShortcut: Bool {
        !selectedScope.isGlobal && context.availableScopes.contains(.global)
    }

    public func present() {
        focusRequestID += 1
    }

    public func updateContext(_ newContext: SearchOverlayContext) {
        guard context != newContext else { return }
        persistCurrentQuery()

        context = newContext
        selectedScope = newContext.preferredScope
        query = storedQuery(for: selectedScope)
    }

    public func selectScope(_ scope: OverlaySearchScope) {
        guard selectedScope != scope else { return }
        persistCurrentQuery()

        selectedScope = scope
        query = storedQuery(for: scope)
        focusRequestID += 1
    }

    public func switchToGlobalScope(carryCurrentQuery: Bool) {
        guard context.availableScopes.contains(.global) else { return }
        let currentQuery = query

        selectScope(.global)
        if carryCurrentQuery {
            updateActiveQuery(currentQuery)
        }
    }

    public func updateActiveQuery(_ newValue: String) {
        query = newValue
        persistCurrentQuery()
    }

    public func playlistQuery(for playlistID: String) -> String {
        playlistQueries[playlistID] ?? ""
    }

    private func persistCurrentQuery() {
        switch selectedScope {
        case .global:
            globalQuery = query
        case .playlist(let id, _):
            playlistQueries[id] = query
        }
    }

    private func storedQuery(for scope: OverlaySearchScope) -> String {
        switch scope {
        case .global:
            return globalQuery
        case .playlist(let id, _):
            return playlistQueries[id] ?? ""
        }
    }
}
