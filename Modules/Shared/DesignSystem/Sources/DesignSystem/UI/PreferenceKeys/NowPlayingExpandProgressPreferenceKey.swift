import SwiftUI

public struct NowPlayingExpandProgressPreferenceKey: PreferenceKey {
    public static let defaultValue: CGFloat = .zero
    public static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

public extension EnvironmentValues {
    @Entry var nowPlayingExpandProgress: CGFloat = 0.0
}
