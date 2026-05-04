#if os(iOS)
import CoreImage
import Foundation
import ImageIO
import SwiftUI
import UIKit

public actor ArtworkDominantColorExtractor {
    public static let shared = ArtworkDominantColorExtractor()

    private final class CacheIndex {
        private final class Node {
            let key: String
            var previous: Node?
            var next: Node?

            init(key: String) {
                self.key = key
            }
        }

        private var nodes: [String: Node] = [:]
        private var head: Node?
        private var tail: Node?

        var count: Int {
            nodes.count
        }

        func touch(_ key: String) {
            if let node = nodes[key] {
                moveToFront(node)
                return
            }

            let node = Node(key: key)
            nodes[key] = node
            insertAtFront(node)
        }

        @discardableResult
        func removeLast() -> String? {
            guard let node = tail else { return nil }
            let key = node.key
            remove(key)
            return key
        }

        private func remove(_ key: String) {
            guard let node = nodes.removeValue(forKey: key) else { return }
            unlink(node)
        }

        private func insertAtFront(_ node: Node) {
            node.previous = nil
            node.next = head
            head?.previous = node
            head = node

            if tail == nil {
                tail = node
            }
        }

        private func moveToFront(_ node: Node) {
            guard head !== node else { return }
            unlink(node)
            insertAtFront(node)
        }

        private func unlink(_ node: Node) {
            let previous = node.previous
            let next = node.next

            previous?.next = next
            next?.previous = previous

            if head === node {
                head = next
            }

            if tail === node {
                tail = previous
            }

            node.previous = nil
            node.next = nil
        }
    }

    private let context = CIContext()
    private let rgbColorSpace = CGColorSpaceCreateDeviceRGB()

    private var cache: [String: UIColor] = [:]
    private let cacheIndex = CacheIndex()
    private let maxCacheEntries = 128

    public init() {}

    public func dominantColor(from imageData: Data, cacheKey: String?) -> Color {
        Color(uiColor: dominantUIColor(from: imageData, cacheKey: cacheKey))
    }

    public func dominantUIColor(from imageData: Data, cacheKey: String?) -> UIColor {
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
        cacheIndex.touch(key)
    }

    private func trimCacheIfNeeded() {
        while cacheIndex.count > maxCacheEntries {
            guard let staleKey = cacheIndex.removeLast() else { break }
            cache[staleKey] = nil
        }
    }

    private func extractDominantColor(from imageData: Data) -> UIColor? {
        guard let image = downsampledImage(from: imageData) ?? CIImage(data: imageData) ?? UIImage(data: imageData).flatMap({ CIImage(image: $0) }) else {
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

    private func downsampledImage(from imageData: Data) -> CIImage? {
        let sourceOptions = [
            kCGImageSourceShouldCache: false
        ] as CFDictionary

        guard let source = CGImageSourceCreateWithData(imageData as CFData, sourceOptions) else {
            return nil
        }

        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: false,
            kCGImageSourceShouldCache: false,
            kCGImageSourceThumbnailMaxPixelSize: 96
        ] as CFDictionary

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
            return nil
        }

        return CIImage(cgImage: cgImage)
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
        
        let boostedSaturation = min(saturation * 1.2, 1.0)
        let boostedBrightness = min(brightness * 1.05, 1.0)

        return UIColor(
            hue: hue,
            saturation: boostedSaturation,
            brightness: boostedBrightness,
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
