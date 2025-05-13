//
//  PlayerProperties.swift
//  cisum
//
//  Created by Aarav Gupta (github.com/atpugvaraa) on 04/05/25.
//

import SwiftUI

@Observable
class PlayerProperties {
    static let shared = PlayerProperties()
    
    private var mainWindow: UIWindow?
    
    // View Properties
    var expandPlayer: Bool = false
    var offsetY: CGFloat = 0
    var windowProgress: CGFloat = 0
    var currentOrientation: UIDeviceOrientation = .portrait
    
    // Now Playing Properties
    var isRotating = Double.random(in: 0 ..< 360)
    var saturation = Double.random(in: 0.7...2)
    var transparency: Double = 0.0
    
    let timer = Timer.publish(every: 6, on: .main, in: .common).autoconnect()
    
    init() {
        if let window = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.keyWindow, mainWindow == nil {
            mainWindow = window
        }
        
        // Initialize with current orientation
        currentOrientation = UIDevice.current.orientation.isValidInterfaceOrientation ? UIDevice.current.orientation : .portrait
    }
    
    // Window resize methods
    func resetWindowToIdentity() {
        mainWindow?.subviews.first?.transform = .identity
    }
    
    func resizeWindow(_ progress: CGFloat) {
        if let mainWindow = mainWindow?.subviews.first {
            let offsetY = (mainWindow.frame.height * progress) / 2
            
            /// Corner Radius
            mainWindow.layer.cornerRadius = (progress / 0.1) * 30
            mainWindow.layer.masksToBounds = true
            
            mainWindow.transform = .identity.scaledBy(x: 1 - progress, y: 1 - progress).translatedBy(x: 0, y: offsetY)
        }
    }
    
    func resetWindowWithAnimation() {
        if let mainWindow = mainWindow?.subviews.first {
            UIView.animate(withDuration: 0.3) {
                mainWindow.layer.cornerRadius = 0
                mainWindow.transform = .identity
            }
        }
    }
    
    func handleOrientationChange(_ newOrientation: UIDeviceOrientation) {
            // Only process valid interface orientations
            guard newOrientation.isValidInterfaceOrientation else { return }
            
            let oldOrientation = currentOrientation
            currentOrientation = newOrientation
            
            // If orientation actually changed and player is expanded
            if oldOrientation != newOrientation && expandPlayer {
                // First reset to identity to avoid transform stacking
                resetWindowToIdentity()
                
                // Then reapply the current transform with a slight delay to ensure the window has updated its frame
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    guard let self = self, self.expandPlayer else { return }
                    self.resizeWindow(0.1 - self.windowProgress)
                }
            }
        }
}
