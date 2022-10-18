//
//  AVAsset-extensions.swift
//  ScaleAudio
//
//  Read discussion at:
//  http://www.limit-point.com/blog/2022/scale-audio/
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
    
    // Note: the number of samples per buffer may change, resulting in different bufferCounts
    func bufferCounts(_ outputSettings:[String : Any]) -> (bufferCount:Int, bufferSampleCount:Int) {
        
        var bufferSampleCount:Int = 0
        var bufferCount:Int = 0
        
        guard let audioTrack = self.tracks(withMediaType: .audio).first else {
            return (bufferCount, bufferSampleCount)
        }
        
        if let audioReader = try? AVAssetReader(asset: self)  {
            
            let audioReaderOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: outputSettings)
            audioReader.add(audioReaderOutput)
            
            if audioReader.startReading() {
                                
                while audioReader.status == .reading {
                    if let sampleBuffer = audioReaderOutput.copyNextSampleBuffer() {
                        bufferSampleCount += sampleBuffer.numSamples
                        bufferCount += 1
                    }
                    else {
                        audioReader.cancelReading()
                    }
                }
            }
        }
        
        return (bufferCount, bufferSampleCount)
    }
}
