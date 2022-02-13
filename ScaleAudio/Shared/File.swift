//
//  File.swift
//  ScaleAudio
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

