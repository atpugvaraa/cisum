import Foundation
import SwiftUI
import Observation
import Services

@Observable
@MainActor
public final class ArtworkController {
    public var currentAccentColor: Color = .gray
    public var videoStatus: ArtworkVideoProcessingStatus = .idle
    public var animatedVideoURL: URL?
    public var videoProgress: Double?
    public var videoError: String?
    
    public init() {}
    
    public func reset() {
        videoStatus = .idle
        animatedVideoURL = nil
        videoProgress = nil
        videoError = nil
    }
    
    public func updateAccentColor(_ color: Color) {
        withAnimation(.smooth) {
            currentAccentColor = color
        }
    }
}
