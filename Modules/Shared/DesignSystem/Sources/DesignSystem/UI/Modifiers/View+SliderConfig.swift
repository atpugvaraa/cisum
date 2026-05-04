//
//  View+SliderConfig.swift
//  cisum
//
//  Created by Aarav Gupta on 16/03/26.
//

#if os(iOS)
import SwiftUI

extension View {
    public func sliderStyle(_ config: SliderConfig) -> some View {
        environment(\.sliderConfig, config)
    }
}
#endif
