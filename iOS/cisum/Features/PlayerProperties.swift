//
//  PlayerProperties.swift
//  cisum
//
//  Created by Aarav Gupta (github.com/atpugvaraa) on 04/05/25.
//

import SwiftUI
import Combine
#if os(iOS)
import UIKit
#endif

@Observable
class PlayerProperties {
    static let shared = PlayerProperties()

    #if os(iOS)
    private var mainWindow: UIWindow?
    #endif
    
    // View Properties
    var isPlayerExpanded: Bool = false
    var offsetY: CGFloat = 0
    var windowProgress: CGFloat = 0
    #if os(iOS)
    var currentOrientation: UIDeviceOrientation = .portrait
    #endif
    
    // Now Playing Properties
    var isRotating = Double.random(in: 0 ..< 360)
    var saturation = Double.random(in: 0.7...2)
    var transparency: Double = 0.0
    
    let timer = Timer.publish(every: 6, on: .main, in: .common).autoconnect()
    
    init() {
        #if os(iOS)
        if let window = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.keyWindow, mainWindow == nil {
            mainWindow = window
        }
        
        // Initialize with current orientation
        currentOrientation = UIDevice.current.orientation.isValidInterfaceOrientation ? UIDevice.current.orientation : .portrait
        #endif
    }
    
    func expandPlayer() {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            withAnimation(.smooth(duration: 0.3, extraBounce: 0)) {
                isPlayerExpanded = true
            }
        } else {
            withAnimation(.smooth(duration: 0.3, extraBounce: 0)) {
                isPlayerExpanded = true
            }

            #if os(iOS)
            /// Resizing window when opening player
            UIView.animate(withDuration: 0.3) {
                self.resizeWindow(0.1)
            }
            #endif
        }
        #else
        withAnimation(.smooth(duration: 0.3, extraBounce: 0)) {
            isPlayerExpanded = true
        }
        #endif
    }
    
    // Window resize methods
    func resetWindowToIdentity() {
        #if os(iOS)
        mainWindow?.subviews.first?.transform = .identity
        #endif
    }
    
    func resizeWindow(_ progress: CGFloat) {
        #if os(iOS)
        if let mainWindow = mainWindow?.subviews.first {
            let offsetY = (mainWindow.frame.height * progress) / 2
            
            /// Corner Radius
            mainWindow.layer.cornerRadius = (progress / 0.1) * 30
            mainWindow.layer.masksToBounds = true
            
            mainWindow.transform = .identity.scaledBy(x: 1 - progress, y: 1 - progress).translatedBy(x: 0, y: offsetY)
        }
        #endif
    }
    
    func resetWindowWithAnimation() {
        #if os(iOS)
        if let mainWindow = mainWindow?.subviews.first {
            UIView.animate(withDuration: 0.3) {
                mainWindow.layer.cornerRadius = 0
                mainWindow.transform = .identity
            }
        }
        #endif
    }
    
    #if os(iOS)
    func handleOrientationChange(_ newOrientation: UIDeviceOrientation) {
        // Only process valid interface orientations
        guard newOrientation.isValidInterfaceOrientation else { return }
        
        let oldOrientation = currentOrientation
        currentOrientation = newOrientation
        
        // If orientation actually changed and player is expanded
        if oldOrientation != newOrientation && isPlayerExpanded {
            // First reset to identity to avoid transform stacking
            resetWindowToIdentity()
            
            // Then reapply the current transform with a slight delay to ensure the window has updated its frame
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self = self, self.isPlayerExpanded else { return }
                self.resizeWindow(0.1 - self.windowProgress)
            }
        }
    }
    #endif
}
