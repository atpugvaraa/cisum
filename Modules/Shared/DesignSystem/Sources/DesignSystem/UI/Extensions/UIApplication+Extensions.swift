//
//  UIApplication+Extensions.swift
//  
//
//  Created by Aarav Gupta on 08/04/26.
//

#if canImport(UIKit)
import UIKit

extension UIApplication {
    static var keyWindow: UIWindow? {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.keyWindow
    }
}
#endif
