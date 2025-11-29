//
//  Tab.swift
//  cisum
//
//  Created by Aarav Gupta on 05/12/25.
//

import SwiftUI

/// A custom implementation of `Tab` that works on iOS 17+.
/// We removed the <Content> generic from the Struct definition.
public struct Tab<SelectionValue: Hashable> {
    
    public let data: TabViewData<SelectionValue>
    
    // The 'init' is still generic, but it erases the type immediately to AnyView
    public init<Content: View>(_ title: String, systemImage: String, value: SelectionValue, role: TabRole? = nil, @ViewBuilder content: () -> Content) {
        self.data = TabViewData(
            title: title,
            icon: systemImage,
            value: value,
            role: role,
            content: AnyView(content())
        )
    }
}
