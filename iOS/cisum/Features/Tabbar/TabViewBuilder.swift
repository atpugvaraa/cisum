//
//  TabViewBuilder.swift
//  cisum
//
//  Created by Aarav Gupta on 05/12/25.
//

import SwiftUI

@resultBuilder
public struct TabViewBuilder<SelectionValue: Hashable> {
    public static func buildBlock(_ components: Tab<SelectionValue>...) -> [TabViewData<SelectionValue>] {
        return components.map { $0.data }
    }
}
