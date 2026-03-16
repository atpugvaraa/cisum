//
//  SizePreferenceKey.swift
//  cisum
//
//  Created by Aarav Gupta (github.com/atpugvaraa) on 04/05/25.
//

import SwiftUI

struct SizePreferenceKey: PreferenceKey {
    nonisolated static var defaultValue: CGSize { .zero }

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}
