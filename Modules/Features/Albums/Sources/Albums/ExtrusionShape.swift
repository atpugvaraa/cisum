//
//  ExtrusionShape.swift
//  Albums
//
//  Created by Aarav Gupta on 19/05/26.
//

import SwiftUI

// MARK: - Shapes

struct ExtrusionShape: Shape {
    var offset: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX - offset, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX, y: offset))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: offset, y: rect.maxY))
        path.addLine(to: CGPoint(x: 0, y: rect.maxY - offset))
        path.closeSubpath()
        
        return path
    }
}
