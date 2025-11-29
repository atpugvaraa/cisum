//
//  TabViewData.swift
//  cisum
//
//  Created by Aarav Gupta on 05/12/25.
//

import SwiftUI

/// Data model representing a Tab.
public struct TabViewData<SelectionValue: Hashable>: Identifiable {
    
    // CHANGED: Use the value itself as the ID, not a random UUID
    public var id: SelectionValue { value }
    
    public var title: String
    public var icon: String
    public var value: SelectionValue
    public var role: TabRole?
    public var content: AnyView
    
    public init(title: String, icon: String, value: SelectionValue, role: TabRole? = nil, content: AnyView) {
        self.title = title
        self.icon = icon
        self.value = value
        self.role = role
        self.content = content
    }
}
