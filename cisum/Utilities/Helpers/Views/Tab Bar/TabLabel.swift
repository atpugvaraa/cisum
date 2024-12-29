//
//  TabLabel.swift
//  cisum
//
//  Created by Aarav Gupta on 29/12/24.
//

import SwiftUI

// MARK: - Supporting View
struct TabLabel: View {
    let tab: SelectedTab
    
    var body: some View {
        VStack {
            Image(systemName: tab.icon)
            Text(tab.title)
        }
    }
}
