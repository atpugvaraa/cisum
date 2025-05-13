//
//  View+Extensions.swift
//  cisum
//
//  Created by Aarav Gupta (github.com/atpugvaraa) on 27/12/24.
//

import SwiftUI

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
