//
//  PlayerExpandAnimation.swift
//  
//
//  Created by Aarav Gupta on 13/04/26.
//

import SwiftUI

public extension Animation {
    public static let playerExpandAnimationDuration: TimeInterval = 0.3

    public static var playerExpandAnimation: Animation {
        .spring(response: 0.5, dampingFraction: 0.8)
    }
    
    public static var sidebarExpandAnimation: Animation {
        .snappy(duration: playerExpandAnimationDuration)
    }
}
