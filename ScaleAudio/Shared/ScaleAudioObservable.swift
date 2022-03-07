//
//  ScaleAudioObservable.swift
//  ScaleAudio
//
//  Created by Joseph Pagliaro on 2/11/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import Foundation
import AVFoundation

let kAudioFilesSubdirectory = "Audio Files"
let kAudioExtensions: [String] = ["aac", "m4a", "aiff", "aif", "wav", "mp3", "caf", "m4r", "flac", "mp4"]
let kAudioFileTypes: [AVFileType] = [AVFileType.m4a, AVFileType.m4a, AVFileType.aiff, AVFileType.aiff, AVFileType.wav, AVFileType.m4a, AVFileType.caf, AVFileType.m4a, AVFileType.m4a, AVFileType.mp4]

func AVFileTypeForExtension(ext:String) -> AVFileType {
    if let index = kAudioExtensions.firstIndex(of: ext) {
        return kAudioFileTypes[index]
    }
    return AVFileType.m4a
}

func ExtensionForAVFileType(_ type:AVFileType) -> String {
    if let ext =  UTType(type.rawValue)?.preferredFilenameExtension {
        return ext
    }
    return "m4a"
}

class ScaleAudioObservable: ObservableObject  {
    
    @Published var files:[File]
    
    @Published var scaledAudioURL:URL?
    
    @Published var progress:Double = 0
    @Published var progressTitle:String = "Progress"
    @Published var isScaling:Bool = false
    
    @Published var factor:Double = 1.5
    @Published var singleChannel:Bool = false
    
    var documentsURL:URL
    
    var audioPlayer: AVAudioPlayer? // hold on to it!
    
    var filename = ""
    var scaledAudioDuration:String = "[00:00]"
    
    let scaleAudio = ScaleAudio()
    
    func scale(url:URL, avFileType:AVFileType, saveTo:String, completion: @escaping (Bool, URL, String?) -> ()) {
        
        let scaledURL = documentsURL.appendingPathComponent(saveTo)
        
        let asset = AVAsset(url: url)
        
        let scaleQueue = DispatchQueue(label: "com.limit-point.scaleQueue")
        
        scaleQueue.async {
            self.scaleAudio.scaleAudio(asset: asset, factor: self.factor, singleChannel: self.singleChannel, destinationURL: scaledURL, avFileType: avFileType, progress: { value, title in
                
                DispatchQueue.main.async {
                    self.progress = value
                    self.progressTitle = title
                }
            }) { (success, failureReason) in
                completion(success, scaledURL, failureReason)
            }
        }
        
    }
    
    func scaleAudioURL(url:URL) {
        
        progress = 0
        isScaling = true
        
        filename = url.lastPathComponent
        
        // output extension should match AVFileType
        let avFileType = AVFileTypeForExtension(ext: url.pathExtension)
        let scaledExtension = ExtensionForAVFileType(avFileType)
        
        scale(url: url, avFileType:avFileType, saveTo: "SCALED.\(scaledExtension)") { (success, scaledURL, failureReason) in
            
            if success {
                
                print("SUCCESS! - scaled URL = \(scaledURL)")
                self.completionSound()
            }
            else {
                print("FAILED! - Failure Reason = \(failureReason ?? "No reason provided.")")
            }
            DispatchQueue.main.async {
                self.progress = 0
                if success {
                    let asset = AVAsset(url: scaledURL)
                    self.progressTitle = "Scaled '\(self.filename)' [\(asset.durationText)]"
                }
                else {
                    self.progressTitle = "Scaling had an error for '\(self.filename)'"
                }
                self.scaledAudioURL = scaledURL
                self.isScaling = false
            }
    
        } 
    }
    
    func loadPlayAudioURL(forResource:String, withExtension: String) {
        
        var audioURL:URL?
        
        if let url = Bundle.main.url(forResource: forResource, withExtension: withExtension, subdirectory: kAudioFilesSubdirectory) {
            audioURL = url
        }
        
        if let audioURL = audioURL {
            playAudioURL(audioURL)
        }
        else {
            print("Can't load audio url!")
        }
    }
    
    func completionSound() {
        if let url = Bundle.main.url(forResource: "Echo", withExtension: "m4a") {
            playAudioURL(url)
        }
    }
    
    func playAudioURL(_ url:URL) {
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)         
            
            if let audioPlayer = audioPlayer {
                audioPlayer.prepareToPlay()
                audioPlayer.play()
            }
            
        } catch let error {
            print(error.localizedDescription)
        }
        
    }
    
    init() {
        let fm = FileManager.default
        documentsURL = try! fm.url(for:.documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        
        self.files = []
        
        for audioExtension in kAudioExtensions {
            if let urls = Bundle.main.urls(forResourcesWithExtension: audioExtension, subdirectory: kAudioFilesSubdirectory) {
                for url in urls {
                    self.files.append(File(url: url))
                }
            }
        }
        
        self.files.sort(by: { $0.url.lastPathComponent > $1.url.lastPathComponent })
        
    }
}
