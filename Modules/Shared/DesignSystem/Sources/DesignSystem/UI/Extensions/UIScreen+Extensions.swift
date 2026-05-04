//
//  UIScreen+Extensions.swift
//  
//
//  Created by Aarav Gupta on 08/04/26.
//

#if canImport(UIKit)
import UIKit

public extension UIScreen {
    static var deviceCornerRadius: CGFloat {
        main.value(forKey: "_displayCornerRadius") as? CGFloat ?? 0
    }

    static var hairlineWidth: CGFloat {
        1 / main.scale
    }

    static let size = UIScreen.main.bounds.size
}
#endif
