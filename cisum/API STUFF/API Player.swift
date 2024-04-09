//
//  API Player.swift
//  cisum
//
//  Created by Aarav Gupta on 31/03/2024.
//

import SwiftUI
import WebKit

struct APIPlayer: UIViewRepresentable {
    var videoID: String

    func makeUIView(context: Context) -> WKWebView {
        return WKWebView()
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
         guard let youtubeURL = URL(string: "https://www.youtube.com/embed/\(videoID)") else { return }
         uiView.scrollView.isScrollEnabled = false
         uiView.load(URLRequest(url: youtubeURL))
    }
}
