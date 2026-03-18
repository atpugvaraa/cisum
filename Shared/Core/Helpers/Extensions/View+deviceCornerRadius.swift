//
//  View+deviceCornerRadius.swift
//  cisum
//
//  Created by Aarav Gupta (github.com/atpugvaraa) on 07/01/25.
//

import SwiftUI

extension View {
    var deviceCornerRadius: CGFloat {
        #if os(iOS)
        let key = "_displayCornerRadius"
        if let screen = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.screen {
            if let cornerRadius = screen.value(forKey: key) as? CGFloat {
                return cornerRadius
            }
            return 0
        }
        return 0
        #else
        return 0
        #endif
    }
}
