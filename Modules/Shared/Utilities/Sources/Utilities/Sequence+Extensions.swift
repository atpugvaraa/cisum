//
//  Sequence+Extensions.swift
//  cisum
//
//  Created by Aarav Gupta on 27/04/26.
//

import Foundation

public extension Sequence {
    /// Returns an array with duplicates removed while preserving order.
    /// Elements must be Hashable.
    func removeDuplicates() -> [Element] where Element: Hashable {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
    
    /// Returns an array with duplicates removed based on a specific key while preserving order.
    func removeDuplicates<T: Hashable>(on keyPath: (Element) -> T) -> [Element] {
        var seen = Set<T>()
        return filter { seen.insert(keyPath($0)).inserted }
    }
}
