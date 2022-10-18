//
//  ScaleAudio.swift
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
import CoreServices
import Accelerate

let kAudioReaderSettings = [
    AVFormatIDKey: Int(kAudioFormatLinearPCM) as AnyObject,
    AVLinearPCMBitDepthKey: 16 as AnyObject,
    AVLinearPCMIsBigEndianKey: false as AnyObject,
    AVLinearPCMIsFloatKey: false as AnyObject,
    //AVNumberOfChannelsKey: 1 as AnyObject, // Set to 1 to read all channels merged into one
    AVLinearPCMIsNonInterleaved: false as AnyObject]

let kAudioWriterExpectsMediaDataInRealTime = false
let kScaleAudioQueue = "com.limit-point.scale-audio-queue"

class ScaleAudio {
    
    var avFileType:AVFileType?
    
    var currentProgress:Double = 0
    var progress:((Double, String) -> ()) = { value,_ in print("progress = \(value)") }
    
        // must add up to 1
    var readAndScaleAudioSamples_ProgressWeight = 0.33
    var interleave_arrays_ProgressWeight = 0.33
    var scaleAudioSamples_ProgressWeight = 0.24
    var sampleBuffersForSamples_ProgressWeight = 0.05
    var saveSampleBuffersToFile_ProgressWeight = 0.05
    
    func updateProgress(counter:Int, lastCounter:Int? = nil, totalCount:Int, weight:Double, label:String, condition:Bool) {
        
        guard totalCount > 0 else {
            return
        }

        var multiplicity:Int = 1
        if let lastCounter = lastCounter, counter > lastCounter  {
            multiplicity = counter - lastCounter
        }
        
        var percent = Double(counter) / Double(totalCount)
        let percentChange = Double(multiplicity) / Double(totalCount)
        currentProgress += (percentChange * weight)

        currentProgress = min(max(currentProgress, 0), 1)
        percent = min(max(percent, 0), 1)
        
        if condition { progress(currentProgress, "\(label) \(Int(percent * 100))%") }
    }
        
    func audioReader(asset:AVAsset, outputSettings: [String : Any]?) -> (audioTrack:AVAssetTrack?, audioReader:AVAssetReader?, audioReaderOutput:AVAssetReaderTrackOutput?) {
        
        if let audioTrack = asset.tracks(withMediaType: .audio).first {
            if let audioReader = try? AVAssetReader(asset: asset)  {
                let audioReaderOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: outputSettings)
                return (audioTrack, audioReader, audioReaderOutput)
            }
        }
        
        return (nil, nil, nil)
    }
    
    func extractSamples(_ sampleBuffer:CMSampleBuffer) -> [Int16]? {
        
        if let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) {
            
            let sizeofInt16 = MemoryLayout<Int16>.size
            
            let bufferLength = CMBlockBufferGetDataLength(dataBuffer)
            
            var data = [Int16](repeating: 0, count: bufferLength / sizeofInt16)
            
            CMBlockBufferCopyDataBytes(dataBuffer, atOffset: 0, dataLength: bufferLength, destination: &data)
            
            return data
        }
        
        return nil
    }
    
    func readAndScaleAudioSamples(asset:AVAsset, factor:Double, singleChannel:Bool) -> (Int, Int, CMAudioFormatDescription?, [Int16]?)? {
        
        progress(currentProgress, "Reading audio")
        
        var outputSettings:[String : Any] = kAudioReaderSettings
        
        if singleChannel {
            outputSettings[AVNumberOfChannelsKey] = 1 as AnyObject
            
            readAndScaleAudioSamples_ProgressWeight = 0.4
            interleave_arrays_ProgressWeight = 0
            scaleAudioSamples_ProgressWeight = 0.4
            sampleBuffersForSamples_ProgressWeight = 0.1
            saveSampleBuffersToFile_ProgressWeight = 0.1
        }
        else {
            readAndScaleAudioSamples_ProgressWeight = 0.33
            interleave_arrays_ProgressWeight = 0.33
            scaleAudioSamples_ProgressWeight = 0.24
            sampleBuffersForSamples_ProgressWeight = 0.05
            saveSampleBuffersToFile_ProgressWeight = 0.05
        }
        
        let totalSamplesCount = asset.bufferCounts(outputSettings).bufferSampleCount
        
        let (_, reader, readerOutput) = self.audioReader(asset:asset, outputSettings: outputSettings)
        
        guard let audioReader = reader,
              let audioReaderOutput = readerOutput
        else {
            return nil
        }
        
        if audioReader.canAdd(audioReaderOutput) {
            audioReader.add(audioReaderOutput)
        }
        else {
            return nil
        }
        
        var bufferSize:Int = 0
        var channelCount:Int = 0
        var formatDescription:CMAudioFormatDescription?
        var audioSamples:[[Int16]] = [[]] // one for each channel
                
        var bufferSamplesCount:Int = 0
        var lastBufferSamplesCount:Int = 0
                
        if audioReader.startReading() {
            
            while audioReader.status == .reading {
                
                autoreleasepool { () -> Void in
                    
                    if let sampleBuffer = audioReaderOutput.copyNextSampleBuffer(), let bufferSamples = self.extractSamples(sampleBuffer) {
                        
                        bufferSamplesCount += sampleBuffer.numSamples
                        updateProgress(counter:bufferSamplesCount, lastCounter: lastBufferSamplesCount, totalCount:totalSamplesCount, weight:readAndScaleAudioSamples_ProgressWeight, label:"Reading audio", condition:true)
                        lastBufferSamplesCount = bufferSamplesCount
                        
                        formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer)
                        
                        if let audioStreamBasicDescription = formatDescription?.audioStreamBasicDescription {
                                                        
                            if bufferSize == 0 {
                                channelCount = Int(audioStreamBasicDescription.mChannelsPerFrame)
                                bufferSize = bufferSamples.count
                                audioSamples = [[Int16]](repeating: [], count: channelCount)
                            }
                            
                                // extract channels
                            let channels = bufferSamples.extract_array_channels(channelCount: channelCount)
                            
                            for (index, channel) in channels.enumerated() {
                                audioSamples[index].append(contentsOf: channel)
                            }
                        }
                    }
                    else {
                        audioReader.cancelReading()
                    }
                }
            }
        }
        
        let scaledAudioSamples = scaleAudioSamples(audioSamples, factor: factor)
        
        return (bufferSize, channelCount, formatDescription, scaledAudioSamples)
    }
    
    func interleave_arrays(_ arrays:[[Int16]]) -> [Int16]? {
        
        guard arrays.count > 0 else { return nil }
        
        if arrays.count == 1 {
            return arrays[0]
        }
        
        progress(currentProgress, "Interleaving")
        
        var size = Int.max
        for m in 0...arrays.count-1 {
            size = min(size, arrays[m].count)
        }
        
        guard size > 0 else { return nil }
        
        let interleaved_length = size * arrays.count
        var interleaved:[Int16] = [Int16](repeating: 0, count: interleaved_length)
        
        var lastDate = Date()
        var totalElapsed:TimeInterval = 0
        
        var count:Int = 0
        for j in 0...size-1 {
            for i in 0...arrays.count-1 {
                interleaved[count] = arrays[i][j]
                count += 1
                
                let elapsed = Date().timeIntervalSince(lastDate)
                lastDate = Date()
                
                totalElapsed += elapsed

                updateProgress(counter:count, totalCount:interleaved_length, weight:interleave_arrays_ProgressWeight, label:"Interleaving", condition:totalElapsed > 1)
                
                if totalElapsed > 1 {
                    totalElapsed = 0
                }
            }
        }
        
        return interleaved 
    }
    
    func scaleAudioSamples(_ audioSamples:[[Int16]], factor:Double) -> [Int16]? {
                
        var scaledAudioSamplesChannels:[[Int16]] = []
        
        progress(currentProgress, "Scaling")
        
        for (index, audioSamplesChannel) in audioSamples.enumerated() {
            
            let length = Int(Double(audioSamplesChannel.count) * factor)
            
            scaledAudioSamplesChannels.append(audioSamplesChannel.scaleToD(length: length, smoothly: true)) 
            
            updateProgress(counter:index+1, totalCount:audioSamples.count, weight:scaleAudioSamples_ProgressWeight, label:"Scaling", condition:true)
        }
        
        return interleave_arrays(scaledAudioSamplesChannels)
    }
    
        // multi channel
    func sampleBufferForSamples(audioSamples:[Int16], channelCount:Int, formatDescription:CMAudioFormatDescription) -> CMSampleBuffer? {
        
        var sampleBuffer:CMSampleBuffer?
        
        let bytesInt16 = MemoryLayout<Int16>.stride
        let dataSize = audioSamples.count * bytesInt16
        
        var samplesBlock:CMBlockBuffer? 
        
        let memoryBlock:UnsafeMutableRawPointer = UnsafeMutableRawPointer.allocate(
            byteCount: dataSize,
            alignment: MemoryLayout<Int16>.alignment)
        
        let _ = audioSamples.withUnsafeBufferPointer { buffer in
            memoryBlock.initializeMemory(as: Int16.self, from: buffer.baseAddress!, count: buffer.count)
        }
        
        if CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault, 
            memoryBlock: memoryBlock, 
            blockLength: dataSize, 
            blockAllocator: nil, 
            customBlockSource: nil, 
            offsetToData: 0, 
            dataLength: dataSize, 
            flags: 0, 
            blockBufferOut:&samplesBlock
        ) == kCMBlockBufferNoErr, let samplesBlock = samplesBlock {
                        
            let sampleCount = audioSamples.count / channelCount
            
            if CMSampleBufferCreate(allocator: kCFAllocatorDefault, dataBuffer: samplesBlock, dataReady: true, makeDataReadyCallback: nil, refcon: nil, formatDescription: formatDescription, sampleCount: sampleCount, sampleTimingEntryCount: 0, sampleTimingArray: nil, sampleSizeEntryCount: 0, sampleSizeArray: nil, sampleBufferOut: &sampleBuffer) == noErr, let sampleBuffer = sampleBuffer {
                
                guard sampleBuffer.isValid, sampleBuffer.numSamples == sampleCount else {
                    return nil
                }
            }
        }
        
        return sampleBuffer
    }
    
    func sampleBuffersForSamples(bufferSize:Int, audioSamples:[Int16], channelCount:Int, formatDescription:CMAudioFormatDescription) -> [CMSampleBuffer?] {
        
        progress(currentProgress, "Preparing Samples")
                
        let blockedAudioSamples = audioSamples.blocks(size: bufferSize)
                
        var sampleBuffers:[CMSampleBuffer?] = []
        
        for (index, audioSamples) in blockedAudioSamples.enumerated() {
            
            updateProgress(counter:index+1, totalCount:blockedAudioSamples.count, weight:sampleBuffersForSamples_ProgressWeight, label:"Preparing Samples", condition:true)
            
            let sampleBuffer = sampleBufferForSamples(audioSamples: audioSamples, channelCount:channelCount, formatDescription: formatDescription)
            
            sampleBuffers.append(sampleBuffer)
        }
        
        return sampleBuffers
    }
    
    func saveSampleBuffersToFile(_ sampleBuffers:[CMSampleBuffer?], formatDescription:CMAudioFormatDescription, destinationURL:URL, completion: @escaping (Bool, String?) -> ())  {
        
        progress(currentProgress, "Writing Samples")
                
        let nbrSamples = sampleBuffers.count
        
        guard nbrSamples > 0  else {
            completion(false, "Invalid buffer count.")
            return
        }
        
        do {
            try FileManager.default.removeItem(at: destinationURL)
        } catch _ {}
        
        guard let avFileType = avFileType, let assetWriter = try? AVAssetWriter(outputURL: destinationURL, fileType: avFileType) else {
            completion(false, "Can't create asset writer.")
            return
        }
                
            // Header: "When a source format hint is provided, the outputSettings dictionary is not required to be fully specified." 
        let audioFormatSettings = [AVFormatIDKey: kAudioFormatLinearPCM] as [String : Any]
        
        if assetWriter.canApply(outputSettings: audioFormatSettings, forMediaType: AVMediaType.audio) == false {
            completion(false, "Can't apply output settings to asset writer.")
            return
        }
        
        let audioWriterInput = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings:audioFormatSettings, sourceFormatHint: formatDescription)
        
        audioWriterInput.expectsMediaDataInRealTime = kAudioWriterExpectsMediaDataInRealTime
        
        if assetWriter.canAdd(audioWriterInput) {
            assetWriter.add(audioWriterInput)
            
        } else {
            completion(false, "Can't add audio input to asset writer.")
            return
        }
        
        let serialQueue: DispatchQueue = DispatchQueue(label: kScaleAudioQueue)
        
        assetWriter.startWriting()
        assetWriter.startSession(atSourceTime: CMTime.zero)
        
        var index = 0
        
        func finishWriting() {
            assetWriter.finishWriting {
                switch assetWriter.status {
                    case .failed:
                        
                        var errorMessage = ""
                        if let error = assetWriter.error {
                            
                            let nserr = error as NSError
                            
                            let description = nserr.localizedDescription
                            errorMessage = description
                            
                            if let failureReason = nserr.localizedFailureReason {
                                print("error = \(failureReason)")
                                errorMessage += ("Reason " + failureReason)
                            }
                        }
                        completion(false, errorMessage)
                        print("errorMessage = \(errorMessage)")
                        return
                    case .completed:
                        print("completed")
                        completion(true, nil)
                        return
                    default:
                        print("failure")
                        completion(false, nil)
                        return
                }
            }
        }
        
        audioWriterInput.requestMediaDataWhenReady(on: serialQueue) {
            
            while audioWriterInput.isReadyForMoreMediaData, index < nbrSamples {
                
                if let currentSampleBuffer = sampleBuffers[index] {
                    audioWriterInput.append(currentSampleBuffer)
                }
                
                index += 1
                
                self.updateProgress(counter:index, totalCount:nbrSamples, weight:self.saveSampleBuffersToFile_ProgressWeight, label:"Writing Samples", condition:true)
                
                if index == nbrSamples {
                    audioWriterInput.markAsFinished()
                    
                    finishWriting()
                }
            }
        }
    }
    
    /**
     Scales all channels in time domain of an audio file into another multi-channel audio file.
     
     Scaling audio is performed in 3 steps using AVFoundation:
     
     1. Read the audio samples of all channels of an audio file, scale all and interleave into an Array of [Int16]
     2. Create an array of sample buffers [CMSampleBuffer] for the array of interleaved scaled audio samples
     3. Write the scaled sample buffers in [CMSampleBuffer] to a file
     
     - Parameter asset: AVAsset - The AVAsset for the audio file to be scaled.
     
     - Parameter factor: Double - A scale factor < 1 slows down the audio, a factor > 1 speeds it up. For example if the audio is originally 10 seconds long and the scale factor is 2 then the scaled audio will be 20 seconds long. If factor is 0.5 then scaled audio will be 5 seconds long.
     
     - Parameter singleChannel: Bool - The AVAssetReader that reads the file can deliver the audio data interleaved with alternating samples from each channel (singleChannel = false) or as a single merged channel (singleChannel = true).
     
     - Parameter destinationURL: URL - A URL that specifies the location for the output file. The extension chosen for this URL should be compatible with the next argument for file type.
     
     - Parameter avFileType: AVFileType - An AVFileType for the desired file type that should be compatible with the previous argument for file extension.
     
     - Parameter progress: An optional handler that is periodically executed to send progress messages and values.
     
     - Parameter completion: A handler that is executed when the operation has completed to send a message of success or not.
     
     */    
    func scaleAudio(asset:AVAsset, factor:Double, singleChannel:Bool, destinationURL:URL, avFileType:AVFileType, progress:((Double, String) -> ())? = nil, completion: @escaping (Bool, String?) -> ())  {
        
        self.avFileType = avFileType
        currentProgress = 0
        
        if let progress = progress {
            self.progress = progress 
        }
        
        guard let (bufferSize, channelCount, formatDescription, audioSamples) = readAndScaleAudioSamples(asset: asset, factor: factor, singleChannel: singleChannel) else {
            completion(false, "Can't read audio samples")
            return
        }
        
        guard let formatDescription = formatDescription else {
            completion(false, "No audio format description")
            return
        }
        
        guard let audioSamples = audioSamples else {
            completion(false, "Can't scale audio samples")
            return
        }
        
        let sampleBuffers = sampleBuffersForSamples(bufferSize: bufferSize, audioSamples: audioSamples, channelCount:channelCount, formatDescription: formatDescription)
        
        saveSampleBuffersToFile(sampleBuffers, formatDescription: formatDescription, destinationURL: destinationURL, completion: completion)
    }
}
