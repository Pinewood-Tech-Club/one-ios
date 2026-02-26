//
//  Widget_ServiceLiveActivity.swift
//  Widget Service
//
//  Created by Adam Xu on 11/23/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct Widget_ServiceAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct Widget_ServiceLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: Widget_ServiceAttributes.self) { context in
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

extension Widget_ServiceAttributes {
    fileprivate static var preview: Widget_ServiceAttributes {
        Widget_ServiceAttributes(name: "World")
    }
}

extension Widget_ServiceAttributes.ContentState {
    fileprivate static var smiley: Widget_ServiceAttributes.ContentState {
        Widget_ServiceAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: Widget_ServiceAttributes.ContentState {
         Widget_ServiceAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: Widget_ServiceAttributes.preview) {
   Widget_ServiceLiveActivity()
} contentStates: {
    Widget_ServiceAttributes.ContentState.smiley
    Widget_ServiceAttributes.ContentState.starEyes
}
