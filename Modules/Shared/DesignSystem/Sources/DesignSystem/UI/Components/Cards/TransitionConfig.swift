import SwiftUI

@MainActor
struct TransitionConfig {
    var cardCornerRadius: CGFloat = 0
    var detailCornerRadius: CGFloat = UIScreen.deviceCornerRadius
    var detailCardHeight: CGFloat = UIScreen.main.bounds.width
    var animation: Animation = .smooth(duration: 0.3, extraBounce: 0)
}
