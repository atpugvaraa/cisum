//
//  ProfileView.swift
//  cisum
//
//  Created by Aarav Gupta on 15/03/26.
//

import SwiftUI

struct ProfileView: View {
    #if DEBUG
    @ObserveInjection var forceRedraw
    #endif

    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
        .enableInjection()
    }
}

#Preview {
    ProfileView()
}
