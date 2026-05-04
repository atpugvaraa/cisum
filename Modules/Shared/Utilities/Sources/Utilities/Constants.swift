//
//  Constants.swift
//
//
//  Created by Aarav Gupta on 08/04/26.
//

import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

public enum AppConstants {
    public static let playerCardPaddings: CGFloat = 32
    public static let screenPaddings: CGFloat = 20
    public static let itemPeekAmount: CGFloat = 36
    public static let dynamicPlayerIslandHeight: CGFloat = 45
    public static let hideThresholds: CGFloat = 20
    public static let showThresholds: CGFloat = -20

    public static var safeAreaInsets: EdgeInsets {
#if canImport(UIKit)
        MainActor.assumeIsolated {
            EdgeInsets(UIApplication.shared.keyWindow?.safeAreaInsets ?? .zero)
        }
#else
        EdgeInsets()
#endif
    }

    public static func itemWidth(
        forItemsPerScreen count: Int,
        spacing: CGFloat = 0,
        containerWidth: CGFloat
    ) -> CGFloat {
        let totalSpacing = spacing * CGFloat(count)
        let availableWidth = containerWidth - screenPaddings - itemPeekAmount - totalSpacing
        return availableWidth / CGFloat(count)
    }
}

#if canImport(UIKit)
public extension EdgeInsets {
    init(_ insets: UIEdgeInsets) {
        self.init(
            top: insets.top,
            leading: insets.left,
            bottom: insets.bottom,
            trailing: insets.right
        )
    }
}
#endif

public extension EdgeInsets {
    static let rowInsets: EdgeInsets = .init(
        top: 0,
        leading: AppConstants.screenPaddings,
        bottom: 0,
        trailing: AppConstants.screenPaddings
    )
}
