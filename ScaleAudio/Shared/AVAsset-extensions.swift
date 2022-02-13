//
//  AVAsset-extensions.swift
//  ScaleAudio
//
//  Created by Joseph Pagliaro on 2/12/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import Foundation
import AVFoundation

extension AVAsset {
    
    var durationText:String {
        let totalSeconds = CMTimeGetSeconds(self.duration)
        return AVAsset.secondsToString(secondsIn: totalSeconds)
    }
    
    class func secondsToString(secondsIn:Double) -> String {
        
        if CGFloat(secondsIn) > (CGFloat.greatestFiniteMagnitude / 2.0) {
            return "∞"
        }
        
        let secondsRounded = round(secondsIn)
        
        let hours:Int = Int(secondsRounded / 3600)
        
        let minutes:Int = Int(secondsRounded.truncatingRemainder(dividingBy: 3600) / 60)
        let seconds:Int = Int(secondsRounded.truncatingRemainder(dividingBy: 60))
        
        
        if hours > 0 {
            return String(format: "%i:%02i:%02i", hours, minutes, seconds)
        } else {
            return String(format: "%02i:%02i", minutes, seconds)
        }
    }
    
}
