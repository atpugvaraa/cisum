//
//  FontRegistration.swift
//  Rechords
//
//  Created by Aarav Gupta on 13/05/26.
//

import CoreText
import SwiftUI

#if canImport(UIKit)
import UIKit
typealias PlatformUIFont = UIFont
#elseif os(macOS)
import AppKit
typealias PlatformUIFont = NSFont
#endif

public enum FontRegistration {
    nonisolated(unsafe) private static var registered = false

    public static func registerFonts() {
        guard !registered else { return }
        registered = true

        guard let fontURL = Bundle.module.url(forResource: "NotoSerif-Italic", withExtension: "ttf") else {
            print("⚠️ Font file not found in bundle")
            return
        }

        var error: Unmanaged<CFError>?
        if !CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &error) {
            print("⚠️ Font registration failed: \(error?.takeRetainedValue().localizedDescription ?? "unknown")")
        }
    }

    public static func printRegisteredFontName() {
        #if canImport(UIKit)
        for family in PlatformUIFont.familyNames.sorted() {
            let names = PlatformUIFont.fontNames(forFamilyName: family)
            if names.contains(where: { $0.lowercased().contains("noto") }) {
                print("Family: \(family)")
                names.forEach { print("  → \($0)") }
            }
        }
        #endif
    }

    public static func testVariableAxes() {
        #if canImport(UIKit)
        guard let font = PlatformUIFont(name: "NotoSerif-Italic", size: 16) else { return }
        #else
        guard let font = PlatformUIFont(name: "NotoSerif-Italic", size: 16) else { return }
        #endif

        if let axes = CTFontCopyVariationAxes(font as CTFont) as? [[String: Any]] {
            for axis in axes {
                print("Axis: \(axis[kCTFontVariationAxisNameKey as String] ?? "")")
                print("  ID:  \(axis[kCTFontVariationAxisIdentifierKey as String] ?? "")")
                print("  Min: \(axis[kCTFontVariationAxisMinimumValueKey as String] ?? "")")
                print("  Max: \(axis[kCTFontVariationAxisMaximumValueKey as String] ?? "")")
            }
        } else {
            print("No variation axes found")
        }
    }
}
