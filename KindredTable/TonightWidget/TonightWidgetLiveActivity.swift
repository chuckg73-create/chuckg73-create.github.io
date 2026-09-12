//
//  TonightWidgetLiveActivity.swift
//  TonightWidget
//
//  Created by Chuck Gallagher on 9/12/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct TonightWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct TonightWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TonightWidgetAttributes.self) { context in
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

extension TonightWidgetAttributes {
    fileprivate static var preview: TonightWidgetAttributes {
        TonightWidgetAttributes(name: "World")
    }
}

extension TonightWidgetAttributes.ContentState {
    fileprivate static var smiley: TonightWidgetAttributes.ContentState {
        TonightWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: TonightWidgetAttributes.ContentState {
         TonightWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: TonightWidgetAttributes.preview) {
   TonightWidgetLiveActivity()
} contentStates: {
    TonightWidgetAttributes.ContentState.smiley
    TonightWidgetAttributes.ContentState.starEyes
}
