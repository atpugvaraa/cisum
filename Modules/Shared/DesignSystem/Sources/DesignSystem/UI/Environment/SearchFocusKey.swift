//
//  SearchFocusKey.swift
//  
//
//  Created by Aarav Gupta on 09/04/26.
//

import SwiftUI

public extension EnvironmentValues {
    public var isSearchExpanded: Binding<Bool> {
        get { self[SearchExpandedKey.self] }
        set { self[SearchExpandedKey.self] = newValue }
    }
}

public struct SearchExpandedKey: EnvironmentKey {
    public static let defaultValue: Binding<Bool> = .constant(false)
}
