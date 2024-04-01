//
//  cisumApp.swift
//  cisum
//
//  Created by Aarav Gupta on 09/03/24.
//

import SwiftUI

@main
struct cisumApp: App {
  let AccentColor = Color(red : 0.9764705882352941, green: 0.17647058823529413, blue: 0.2823529411764706)

    var body: some Scene {
        WindowGroup {
            Main(videoID: "")
            .accentColor(AccentColor)
            .preferredColorScheme(.dark)
        }
    }
}
