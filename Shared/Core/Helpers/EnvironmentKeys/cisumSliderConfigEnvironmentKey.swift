//
//  cisumSliderConfigEnvironmentKey.swift
//  cisum
//
//  Created by Aarav Gupta (github.com/atpugvaraa) on 09/05/25.
//

#if os(iOS)
import SwiftUI

struct cisumSliderConfigEnvironmentKey: EnvironmentKey {
    static let defaultValue: cisumSliderConfig = .init()
}
#endif
