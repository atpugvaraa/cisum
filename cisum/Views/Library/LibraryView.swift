//
//  LibraryView.swift
//  cisum
//
//  Created by Aarav Gupta on 15/03/26.
//

import SwiftUI

struct LibraryView: View {
    #if DEBUG
    @ObserveInjection var forceRedraw
    #endif

    var body: some View {
        Color.blue.overlay(Text("Library View"))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        .enableInjection()
    }
}

#Preview {
    LibraryView()
}
