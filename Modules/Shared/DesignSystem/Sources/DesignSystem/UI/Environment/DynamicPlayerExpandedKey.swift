//
//  SearchExpandedKey.swift
//  
//
//  Created by Aarav Gupta on 15/04/26.
//

import SwiftUI

extension EnvironmentValues {
    var isDynamicPlayerExpanded: Binding<Bool> {
        get { self[DynamicPlayerExpandedKey.self] }
        set { self[DynamicPlayerExpandedKey.self] = newValue }
    }
}

private struct DynamicPlayerExpandedKey: EnvironmentKey {
    static let defaultValue: Binding<Bool> = .constant(false)
}
