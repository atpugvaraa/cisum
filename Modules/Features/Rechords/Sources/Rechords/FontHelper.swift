//
//  FontHelper.swift
//  Rechords
//
//  Created by Aarav Gupta on 13/05/26.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
typealias PlatformFont = UIFont
typealias PlatformFontDescriptor = UIFontDescriptor
#else
import AppKit
typealias PlatformFont = NSFont
typealias PlatformFontDescriptor = NSFontDescriptor
#endif

public func notoSerifItalic(size: CGFloat, weight: CGFloat = 200, width: CGFloat = 100) -> Font {
    FontRegistration.registerFonts()

    let descriptor = PlatformFontDescriptor(fontAttributes: [
        .name: "NotoSerif-Italic",
        kCTFontVariationAttribute as PlatformFontDescriptor.AttributeName: [
            2003265652: weight,  // wght: 100–900
            2003072104: width    // wdth: 62.5–100
        ]
    ])

    let platformFont = PlatformFont(descriptor: descriptor, size: size)
    return Font(platformFont)
}
