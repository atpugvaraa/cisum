//
//  Enum+TabItem.swift
//  cisum
//
//  Created by Aarav Gupta on 05/12/25.
//

import SwiftUI

enum TabItem: String, CaseIterable {
    case home, discover, library, search
    
    var index: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }
}

enum ScrollPhases: Equatable {
    case idle
    case interacting
    case decelerating

    @available(iOS 18.0, *)
    init(_ nativePhase: ScrollPhase) {
        switch nativePhase {
        case .idle:
            self = .idle
        case .interacting:
            self = .interacting
        case .decelerating:
            self = .decelerating
        @unknown default:
            self = .idle
        }
    }
}
