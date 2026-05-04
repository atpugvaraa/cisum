import SwiftUI

public enum TabItem: String, CaseIterable {
    case home, discover, library, search
    
    public var index: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }
}

public enum ScrollPhases: Equatable {
    case idle
    case interacting
    case decelerating

    @available(iOS 18.0, macOS 15.0, *)
    public init(_ nativePhase: ScrollPhase) {
        switch nativePhase {
        case .idle:
            self = .idle
        case .interacting:
            self = .interacting
        case .decelerating:
            self = .decelerating
        case .tracking:
            self = .idle
        case .animating:
            self = .idle
        }
    }
}
