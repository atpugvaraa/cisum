//
//  Color+Extension.swift
//  cisum
//
//  Created by Aarav Gupta on 25/12/25.
//

import SwiftUI

extension Color {
    static var dynamicAccent: Color = .accent
    
    static let cisumBg = Color(hex: "FDF6E3")
    static let cisumSurface = Color(hex: "EEE8D5")
    static let cisumAccent = Color(hex: "CB4B16")
    static let cisumYellow = Color(hex: "B58900")
    static let cisumDark = Color(hex: "2B221B")
    
    init(hex: String) {
        let scanner = Scanner(string: hex)
        _ = scanner.scanString("#")
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >>  8) & 0xFF) / 255.0
        let b = Double((rgb >>  0) & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
