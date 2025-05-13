//
//  TabLabel.swift
//  cisum
//
//  Created by Aarav Gupta (github.com/atpugvaraa) on 29/12/24.
//

import SwiftUI

// MARK: - Supporting View
struct TabLabel: View {
    let tab: SelectedTab
    
    var body: some View {
        VStack {
            #warning("implement custom sfsymbol")
//            if tab == .home {
//                Image(tab.icon)
//            } else {
                Image(systemName: tab.icon)
//            }
            
            Text(tab.title)
        }
    }
}
