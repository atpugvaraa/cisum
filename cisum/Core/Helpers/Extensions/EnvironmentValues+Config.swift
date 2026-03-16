//
//  EnvironmentValues+Config.swift
//  cisum
//
//  Created by Aarav Gupta (github.com/atpugvaraa) on 09/05/25.
//

import SwiftUI

extension EnvironmentValues {
    var cisumSliderConfig: cisumSliderConfig {
        get { self[cisumSliderConfigEnvironmentKey.self] }
        set { self[cisumSliderConfigEnvironmentKey.self] = newValue
        }
    }
}
