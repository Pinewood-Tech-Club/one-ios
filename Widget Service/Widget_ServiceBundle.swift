//
//  Widget_ServiceBundle.swift
//  Widget Service
//
//  Created by Adam Xu on 11/23/25.
//

import WidgetKit
import SwiftUI

@main
struct Widget_ServiceBundle: WidgetBundle {
    var body: some Widget {
        Widget_Service()
        Widget_ServiceControl()
        Widget_ServiceLiveActivity()
    }
}
