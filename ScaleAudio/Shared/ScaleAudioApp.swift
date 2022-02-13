//
//  ScaleAudioApp.swift
//  Shared
//
//  Created by Joseph Pagliaro on 2/11/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import SwiftUI

@main
struct ScaleAudioApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(scaleAudioObservable: ScaleAudioObservable())
        }
    }
}
