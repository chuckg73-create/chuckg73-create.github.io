//
//  TonightWidgetBundle.swift
//  TonightWidget
//
//  Created by Chuck Gallagher on 9/12/26.
//

import WidgetKit
import SwiftUI

@main
struct TonightWidgetBundle: WidgetBundle {
    var body: some Widget {
        TonightWidget()
        TonightWidgetControl()
        TonightWidgetLiveActivity()
    }
}
