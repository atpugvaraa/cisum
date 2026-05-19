//
//  SearchExpandedKey.swift
//  
//
//  Created by Aarav Gupta on 15/04/26.
//

import SwiftUI

public extension EnvironmentValues {
    var isDynamicPlayerExpanded: Binding<Bool> {
        get { self[DynamicPlayerExpandedKey.self] }
        set { self[DynamicPlayerExpandedKey.self] = newValue }
    }
}

public struct DynamicPlayerExpandedKey: EnvironmentKey {
    public static let defaultValue: Binding<Bool> = .constant(false)
}
