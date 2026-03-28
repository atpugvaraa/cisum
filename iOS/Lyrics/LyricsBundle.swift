//
//  LyricsBundle.swift
//  Lyrics
//
//  Created by Aarav Gupta on 21/03/26.
//

import WidgetKit
import SwiftUI

@main
struct LyricsBundle: WidgetBundle {
    var body: some Widget {
        Lyrics()
        LyricsControl()
        LyricsLiveActivity()
    }
}
