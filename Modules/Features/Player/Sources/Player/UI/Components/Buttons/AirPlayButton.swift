//
//  AirPlayButton.swift
//  cisum
//
//  Created by Aarav Gupta on 27/03/26.
//

import SwiftUI
import Services
import AVKit

#if os(iOS)
import UIKit

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
#elseif os(macOS)
import AppKit

struct AirPlayButton: NSViewRepresentable {
    var activeTintColor: NSColor = Color.dynamicAccent.uiColor

    func makeNSView(context: Context) -> AVRoutePickerView {
        let routePickerView = AVRoutePickerView()
        return routePickerView
    }

    func updateNSView(_ nsView: AVRoutePickerView, context: Context) {
    }
}
#endif


