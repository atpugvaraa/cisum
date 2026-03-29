//
//  ArtworkDominantColorExtractor.swift
//  cisum
//
//  Created by GitHub Copilot on 29/03/26.
//

#if os(iOS)
import CoreImage
import Foundation
import SwiftUI
import UIKit

actor ArtworkDominantColorExtractor {
    static let shared = ArtworkDominantColorExtractor()

    private let context = CIContext(options: [.useSoftwareRenderer: false])
    private let rgbColorSpace = CGColorSpaceCreateDeviceRGB()

    private var cache: [String: UIColor] = [:]
    private var lruKeys: [String] = []
    private let maxCacheEntries = 128

    func dominantColor(from imageData: Data, cacheKey: String?) -> Color {
        Color(uiColor: dominantUIColor(from: imageData, cacheKey: cacheKey))
    }

    func dominantUIColor(from imageData: Data, cacheKey: String?) -> UIColor {
        if let cacheKey, let cached = cachedColor(for: cacheKey) {
            return cached
        }

        let extracted = extractDominantColor(from: imageData)
        let normalized = normalize(extracted ?? Self.defaultAccentColor)

        if let cacheKey {
            storeColor(normalized, for: cacheKey)
        }

        return normalized
    }

    private func cachedColor(for key: String) -> UIColor? {
        guard let color = cache[key] else { return nil }
        touchCacheKey(key)
        return color
    }

    private func storeColor(_ color: UIColor, for key: String) {
        cache[key] = color
        touchCacheKey(key)
        trimCacheIfNeeded()
    }

    private func touchCacheKey(_ key: String) {
        if let index = lruKeys.firstIndex(of: key) {
            lruKeys.remove(at: index)
        }
        lruKeys.insert(key, at: 0)
    }

    private func trimCacheIfNeeded() {
        guard lruKeys.count > maxCacheEntries else { return }
        while lruKeys.count > maxCacheEntries {
            let staleKey = lruKeys.removeLast()
            cache[staleKey] = nil
        }
    }

    private func extractDominantColor(from imageData: Data) -> UIColor? {
        guard let image = CIImage(data: imageData) ?? UIImage(data: imageData).flatMap({ CIImage(image: $0) }) else {
            return nil
        }

        let extent = image.extent.integral
        guard !extent.isEmpty else { return nil }

        guard let filter = CIFilter(
            name: "CIAreaAverage",
            parameters: [
                kCIInputImageKey: image,
                kCIInputExtentKey: CIVector(cgRect: extent)
            ]
        ),
        let outputImage = filter.outputImage else {
            return nil
        }

        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(
            outputImage,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: rgbColorSpace
        )

        let alpha = CGFloat(bitmap[3]) / 255.0
        guard alpha > 0.01 else { return nil }

        return UIColor(
            red: CGFloat(bitmap[0]) / 255.0,
            green: CGFloat(bitmap[1]) / 255.0,
            blue: CGFloat(bitmap[2]) / 255.0,
            alpha: 1
        )
    }

    private func normalize(_ color: UIColor) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        guard color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return Self.defaultAccentColor
        }

        let clampedSaturation = min(max(saturation, 0.28), 0.95)
        let clampedBrightness = min(max(brightness, 0.26), 0.84)

        return UIColor(
            hue: hue,
            saturation: clampedSaturation,
            brightness: clampedBrightness,
            alpha: 1
        )
    }

    private static let defaultAccentColor = UIColor(
        red: 203.0 / 255.0,
        green: 75.0 / 255.0,
        blue: 22.0 / 255.0,
        alpha: 1
    )
}
#endif
