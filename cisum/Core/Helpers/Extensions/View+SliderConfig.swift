//
//  View+SliderConfig.swift
//  cisum
//
//  Created by Aarav Gupta on 16/03/26.
//

import SwiftUI

extension View {
    func sliderStyle(_ config: cisumSliderConfig) -> some View {
        environment(\.cisumSliderConfig, config)
    }
}
