//
//  ClosedRange+Comparable.swift
//  cisum
//
//  Created by Aarav Gupta (github.com/atpugvaraa) on 04/05/25.
//

import Foundation

public extension ClosedRange where Bound: AdditiveArithmetic {
    var distance: Bound {
        upperBound - lowerBound
    }
}

public extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}
