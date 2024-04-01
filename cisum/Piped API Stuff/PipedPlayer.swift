////
////  PipedPlayer.swift
////  cisum
////
////  Created by Aarav Gupta on 01/04/24.
////
//
//import SwiftUI
//import WebKit
//
//struct PipedPlayer: UIViewRepresentable {
//    var videoID: String
//
//    func makeUIView(context: Context) -> WKWebView {
//        return WKWebView()
//    }
//
//    func updateUIView(_ uiView: WKWebView, context: Context) {
//        guard let pipedURL = URL(string: "https://pipedapi.kavin.rocks/streams/\(videoID)") else { return }
//        uiView.scrollView.isScrollEnabled = false
//        uiView.load(URLRequest(url: pipedURL))
//    }
//}
