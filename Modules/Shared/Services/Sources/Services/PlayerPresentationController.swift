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
        withAnimation(.playerExpandAnimation) {
            isExpanded = true
        }
    }
    
    public func collapse() {
        withAnimation(.playerExpandAnimation) {
            isExpanded = false
        }
    }
    
    public func toggle() {
        withAnimation(.playerExpandAnimation) {
            isExpanded.toggle()
        }
    }
}
