//
//  LyricsLiveActivity.swift
//  Lyrics
//
//  Created by Aarav Gupta on 21/03/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct LyricsAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct LyricsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LyricsAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension LyricsAttributes {
    fileprivate static var preview: LyricsAttributes {
        LyricsAttributes(name: "World")
    }
}

extension LyricsAttributes.ContentState {
    fileprivate static var smiley: LyricsAttributes.ContentState {
        LyricsAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: LyricsAttributes.ContentState {
         LyricsAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: LyricsAttributes.preview) {
   LyricsLiveActivity()
} contentStates: {
    LyricsAttributes.ContentState.smiley
    LyricsAttributes.ContentState.starEyes
}
