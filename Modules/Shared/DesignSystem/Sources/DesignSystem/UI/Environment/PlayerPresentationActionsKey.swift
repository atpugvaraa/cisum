//
//  PlayerPresentationActionsKey.swift
//  cisum
//
//  Created by Aarav Gupta on 10/04/26.
//

import SwiftUI

public struct PlayerPresentationActions {
    public var expand: () -> Void = {}
    public var collapse: () -> Void = {}
    public var toggle: () -> Void = {}
    
    public init(
        expand: @escaping () -> Void = {},
        collapse: @escaping () -> Void = {},
        toggle: @escaping () -> Void = {}
    ) {
        self.expand = expand
        self.collapse = collapse
        self.toggle = toggle
    }
}

public extension EnvironmentValues {
    public var playerPresentationActions: PlayerPresentationActions {
        get { self[PlayerPresentationActionsKey.self] }
        set { self[PlayerPresentationActionsKey.self] = newValue }
    }
}

public struct PlayerPresentationActionsKey: @preconcurrency EnvironmentKey {
    @MainActor public static let defaultValue: PlayerPresentationActions = .init()
}