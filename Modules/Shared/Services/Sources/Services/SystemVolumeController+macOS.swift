import SwiftUI
import AVFoundation

#if os(macOS)
import AppKit

@Observable @MainActor
public final class SystemVolumeController {
    public enum VolumeButtonEventDirection {
        case up
        case down
    }

    public static let shared = SystemVolumeController()

    public var volume: Double = 0.5
    public var isUserDragging: Bool = false
    public var showsSystemVolumeHUD: Bool = false

    public var onSystemVolumeChanged: ((Float, Float) -> Void)?
    public var onSystemVolumeButtonEvent: ((VolumeButtonEventDirection, Float) -> Void)?

    public init() {
        // macOS specific implementation could go here using AudioObjectPropertyAddress
        // For now, we'll just keep it as a stub that holds state
    }

    public func applyVolumeToSystem() {
        // Implementation for macOS
    }

    public func activate() {}
    public func deactivate() {}
}
#endif
