//
//  View+Extensions.swift
//  cisum
//
//  Created by Aarav Gupta (github.com/atpugvaraa) on 27/12/24.
//

import SwiftUI

extension View {
    func hideKeyboard() {
        #if os(iOS)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
    
    func hideKeyboardOnTap() -> some View {
        #if os(iOS)
        self.gesture(
            TapGesture()
                .onEnded {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
        )
        #else
        self
        #endif
    }
}
