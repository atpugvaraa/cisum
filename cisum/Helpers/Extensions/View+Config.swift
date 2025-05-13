//
//  View+sliderStyle.swift
//  cisum
//
//  Created by Aarav Gupta (github.com/atpugvaraa) on 09/05/25.
//

import SwiftUI

extension View {
    func sliderStyle(_ config: cisumSliderConfig) -> some View {
        environment(\.cisumSliderConfig, config)
    }
    
    func navigationBarStyle(_ style: NavigationBarStyle) -> some View {
        environment(\.navigationBarStyle, style)
    }
}
