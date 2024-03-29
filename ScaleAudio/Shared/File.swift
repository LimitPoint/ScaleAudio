//
//  File.swift
//  ScaleAudio
//
//  Read discussion at:
//  http://www.limit-point.com/blog/2022/scale-audio/
//
//  Created by Joseph Pagliaro on 2/11/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import Foundation
import AVFoundation

struct File: Identifiable {
    var url:URL
    var id = UUID()
    var duration:String {
        let asset = AVAsset(url: url)
        return asset.durationText
    }
}

