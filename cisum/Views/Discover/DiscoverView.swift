//
//  DiscoverView.swift
//  cisum
//
//  Created by Aarav Gupta on 15/03/26.
//

import SwiftUI

struct DiscoverView: View {
    #if DEBUG
    @ObserveInjection var forceRedraw
    #endif

    var body: some View {
        Color.green.overlay(Text("Discover"))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .enableInjection()
    }
}

#Preview {
    DiscoverView()
}
