//
//  AirPlayButton.swift
//  cisum
//
//  Created by Aarav Gupta on 27/03/26.
//

#if os(iOS)

import SwiftUI
import AVKit

struct AirPlayButton: UIViewRepresentable {
    var activeTintColor: UIColor = Color.dynamicAccent.uiColor

    func makeUIView(context: Context) -> AVRoutePickerView {
        let routePickerView = AVRoutePickerView()
        routePickerView.tintColor = .white
        routePickerView.activeTintColor = activeTintColor
        routePickerView.prioritizesVideoDevices = false
        return routePickerView
    }
    
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        uiView.activeTintColor = activeTintColor
    }
}

#endif
