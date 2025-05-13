//
//  ScrollOffsetBackground.swift
//  cisum
//
//  Created by Aarav Gupta (github.com/atpugvaraa) on 18/03/25.
//

import SwiftUI

struct ScrollOffsetBackground: View {
    var onOffsetChange: (CGFloat) -> Void
    var body: some View {
        GeometryReader { geometry in
            Color.clear
                .preference(key: ViewOffsetKey.self, value: geometry.frame(in: .global).minY)
                .onPreferenceChange(ViewOffsetKey.self, perform: onOffsetChange)
        }
    }
}
