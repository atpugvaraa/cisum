import Observation
import Foundation
import SwiftUI

@Observable
@MainActor
public final class PlayerPresentationController {
    public var isExpanded: Bool = false
    
    public init(isExpanded: Bool = false) {
        self.isExpanded = isExpanded
    }
    
    public func expand() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            isExpanded = true
        }
    }
    
    public func collapse() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            isExpanded = false
        }
    }
    
    public func toggle() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            isExpanded.toggle()
        }
    }
}
