//
//  TabViewBuilder.swift
//  cisum
//
//  Created by Aarav Gupta on 05/12/25.
//

import SwiftUI

@resultBuilder
public struct TabViewBuilder<SelectionValue: Hashable> {
    // Now accepts a list of Tab<SelectionValue>, regardless of their content
    public static func buildBlock(_ components: Tab<SelectionValue>...) -> [TabViewData<SelectionValue>] {
        return components.map { $0.data }
    }
}
