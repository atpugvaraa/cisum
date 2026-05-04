//
//  cisumSliderConfigEnvironmentKey.swift
//  cisum
//
//  Created by Aarav Gupta (github.com/atpugvaraa) on 09/05/25.
//

#if os(iOS)
import SwiftUI

public struct SliderConfigEnvironmentKey: EnvironmentKey {
    public static let defaultValue: SliderConfig = .init()
}
#endif
