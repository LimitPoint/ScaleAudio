//
//  ScaleAudioApp.swift
//  Shared
//
//  Read discussion at:
//  http://www.limit-point.com/blog/2022/scale-audio/
//
//  Created by Joseph Pagliaro on 2/11/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import SwiftUI

@main
struct ScaleAudioApp: App {
    
    init() {
        // interpolation samples for blog discussion on decimation
        let x:[Int16] = [3,5,1,8,4,56,33,4,77,42,84,25,12,6,13,15]
        
        for i in 1...x.count+4 {
            print(i)
            print(x)
            let scaled = x.scaleToD(length: i, smoothly: true)
            print(scaled)
            print("scaled.count = \(scaled.count)")
            print("----")
        }
    }
        
    var body: some Scene {
        WindowGroup {
            ContentView(scaleAudioObservable: ScaleAudioObservable())
        }
    }
}
