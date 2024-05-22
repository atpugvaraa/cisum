//
//  ContentView.swift
//  cisum
//
//  Created by Aarav Gupta on 04/05/24.
//

import SwiftUI

struct ContentView: View {
    @StateObject var contentViewModel = ContentViewModel()
    @StateObject var mainViewModel = MainViewModel()
    var body: some View {
        Group {
            if contentViewModel.userSession != nil {
                Main()
            } else {
                OnBoarding()
            }
        }
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
