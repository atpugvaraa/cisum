//
//  NavigationBarVariableBlurView.swift
//  cisum
//
//  Created by Aarav Gupta (github.com/atpugvaraa) on 18/03/25.
//

import SwiftUI
import UIKit

extension UIBlurEffect {
    public static func variableBlurEffect(radius: Double, imageMask: UIImage) -> UIBlurEffect? {
        let methodType = (@convention(c) (AnyClass, Selector, Double, UIImage) -> UIBlurEffect).self
        let selectorName = ["imageMask:", "effectWithVariableBlurRadius:"].reversed().joined()
        let selector = NSSelectorFromString(selectorName)
        guard UIBlurEffect.responds(to: selector) else { return nil }
        let implementation = UIBlurEffect.method(for: selector)
        let method = unsafeBitCast(implementation, to: methodType)
        return method(UIBlurEffect.self, selector, radius, imageMask)
    }
}

// MARK: - UIViewRepresentable for Variable Blur

struct NavigationBarVariableBlurView: UIViewRepresentable {
    // MARK: - Properties
    
    let radius: Double
    let maskHeight: CGFloat
    let fromTop: Bool
    
    // Use a static cache for the mask image with proper access control
    private static var maskCache: [String: UIImage] = [:]
    private static let cacheQueue = DispatchQueue(label: "com.cisum.variableBlurCache", qos: .userInitiated)
    
    // MARK: - Initialization
    
    init(radius: Double, maskHeight: CGFloat, fromTop: Bool) {
        self.radius = radius
        self.maskHeight = maskHeight
        self.fromTop = fromTop
        
        let cacheKey = "\(maskHeight)-\(fromTop)"
        Self.cacheQueue.async {
            if NavigationBarVariableBlurView.maskCache[cacheKey] == nil {
                Task.detached(priority: .userInitiated) {
                    let maskImage = await createGradientImage(maskHeight: maskHeight, fromTop: fromTop)
                    await MainActor.run {
                        NavigationBarVariableBlurView.maskCache[cacheKey] = maskImage
                    }
                }
            }
        }
    }
    
    // MARK: - UIViewRepresentable Methods
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: nil)
        // Make the view non-interactive to allow touches to pass through
        view.isUserInteractionEnabled = false
        return view
    }
    
    func updateUIView(_ view: UIVisualEffectView, context: Context) {
        let cacheKey = "\(maskHeight)-\(fromTop)"
        
        // Check cache first
        var cachedMask: UIImage?
        Self.cacheQueue.sync {
            cachedMask = NavigationBarVariableBlurView.maskCache[cacheKey]
        }
        
        if let cachedMask = cachedMask {
            view.effect = UIBlurEffect.variableBlurEffect(radius: radius, imageMask: cachedMask)
        } else {
            // Set to nil while loading to avoid visual artifacts
            view.effect = nil
            
            Task {
                let maskImage = await createGradientImage(maskHeight: maskHeight, fromTop: fromTop)
                await MainActor.run {
                    Self.cacheQueue.async {
                        NavigationBarVariableBlurView.maskCache[cacheKey] = maskImage
                    }
                    view.effect = UIBlurEffect.variableBlurEffect(radius: radius, imageMask: maskImage)
                }
            }
        }
    }
}

// MARK: - Helper Functions

private func createGradientImage(maskHeight: CGFloat, fromTop: Bool) async -> UIImage {
    
    var safeAreaInsets: UIEdgeInsets {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            return UIEdgeInsets.zero
        }
        
        return window.safeAreaInsets
    }
    
    let screen = await UIScreen.main.bounds
    
    let safeAreaTop = await MainActor.run { safeAreaInsets.top }
    let safeAreaBottom = await MainActor.run { safeAreaInsets.bottom }
    
    return await Task.detached(priority: .userInitiated) {
        autoreleasepool {
            let screenSize = CGSize(
                width: screen.width,
                height: screen.height
            )
            
            let format = UIGraphicsImageRendererFormat()
            format.scale = 0.0 // Use the device's scale
            let renderer = UIGraphicsImageRenderer(size: screenSize, format: format)
            
            return renderer.image { context in
                let cgContext = context.cgContext
                let colorSpace = CGColorSpaceCreateDeviceGray()
                
                let locations: [CGFloat]
                if fromTop {
                    locations = [0.0, safeAreaTop / screenSize.height, (maskHeight + safeAreaTop) / screenSize.height, 1.0]
                } else {
                    locations = [0.0, (screenSize.height - maskHeight - safeAreaBottom) / screenSize.height, (screenSize.height - safeAreaBottom) / screenSize.height, 1.0]
                }
                
                let colors: [CGFloat]
                if fromTop {
                    colors = [0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0]
                } else {
                    colors = [0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 1.0]
                }
                
                guard let gradient = CGGradient(colorSpace: colorSpace, colorComponents: colors, locations: locations, count: locations.count) else {
                    return
                }
                
                let startPoint = CGPoint(x: screenSize.width / 2, y: 0)
                let endPoint = CGPoint(x: screenSize.width / 2, y: screenSize.height)
                
                cgContext.drawLinearGradient(gradient, start: startPoint, end: endPoint, options: [])
            }
        }
    }.value
}

// MARK: - View Modifier

struct VariableBlurModifier: ViewModifier {
    // MARK: - Properties
    
    @State private var isReduceTransparencyEnabled = UIAccessibility.isReduceTransparencyEnabled
    var radius: Double
    var maskHeight: CGFloat
    var fromTop: Bool
    var opacity: CGFloat
    
    // MARK: - Body
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                setupAccessibilityObserver()
            }
            .onDisappear {
                removeAccessibilityObserver()
            }
            .overlay (
                Group {
                    if !isReduceTransparencyEnabled {
                        NavigationBarVariableBlurView(radius: radius, maskHeight: maskHeight, fromTop: fromTop)
                            .opacity(opacity)
                            .ignoresSafeArea()
                            .allowsHitTesting(false)
                    }
                }
            )
    }
    
    // MARK: - Private Methods
    
    private func setupAccessibilityObserver() {
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            isReduceTransparencyEnabled = UIAccessibility.isReduceTransparencyEnabled
        }
    }
    
    private func removeAccessibilityObserver() {
        NotificationCenter.default.removeObserver(
            self,
            name: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
            object: nil
        )
    }
}

// MARK: - View Extension

extension View {
    func variableBlur(radius: Double, maskHeight: CGFloat, fromTop: Bool = true, opacity: CGFloat) -> some View {
        self.modifier(VariableBlurModifier(radius: radius, maskHeight: maskHeight, fromTop: fromTop, opacity: opacity))
    }
}

#Preview {
    VStack(spacing: 0) {
        Circle()
            .foregroundStyle(.red)
        Circle()
            .foregroundStyle(.green)
        Circle()
            .foregroundStyle(.blue)
    }
    .frame(maxWidth: .infinity, alignment: .center)
    .variableBlur(radius: 12, maskHeight: 100, opacity: 1)
}
