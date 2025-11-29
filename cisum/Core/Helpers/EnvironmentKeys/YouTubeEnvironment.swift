//
//  YouTubeEnvironmentKey.swift
//  cisum
//
//  Created by Aarav Gupta on 15/03/26.
//

import SwiftUI
import YouTubeSDK

private struct YouTubeEnvironmentKey: EnvironmentKey {
    static let defaultValue: YouTube = YouTube.shared
}

extension EnvironmentValues {
    var youtube: YouTube {
        get { self[YouTubeEnvironmentKey.self] }
        set { self[YouTubeEnvironmentKey.self] = newValue }
    }
}
