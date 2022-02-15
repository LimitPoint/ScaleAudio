//
//  ScaleAudio.swift
//  ScaleAudio
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

extension Array {
    func blocks(size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

extension Array where Element == Int16  {
    func scaleToD(length:Int, smoothly:Bool) -> [Element] {
        
        guard length > 0 else {
            return []
        }
        
        let stride = vDSP_Stride(1)
        var control:[Double]
                
        if smoothly, length > self.count {
            let denominator = Double(length) / Double(self.count - 1)
            
            control = (0...length).map {
                let x = Double($0) / denominator
                return floor(x) + simd_smoothstep(0, 1, simd_fract(x))
            }
        }
        else {
            var base: Double = 0
            var end = Double(self.count - 1)
            control = [Double](repeating: 0, count: length)
            
            vDSP_vgenD(&base, &end, &control, stride, vDSP_Length(length))
        }
        
        // for interpolation samples in app init
        if control.count <= 16  { // limit to small arrays!
            print("control = \(control)")
        }
        
        var result = [Double](repeating: 0,
                              count: length)
        
        let double_array = vDSP.integerToFloatingPoint(self, floatingPointType: Double.self)
        
        vDSP_vlintD(double_array,
                    control, stride,
                    &result, stride,
                    vDSP_Length(length),
                    vDSP_Length(double_array.count))
        
        return vDSP.floatingPointToInteger(result, integerType: Int16.self, rounding: .towardNearestInteger)
    }
    
    func extract_array_channel(channelIndex:Int, channelCount:Int) -> [Int16]? {
        
        guard channelIndex >= 0, channelIndex < channelCount, self.count > 0 else { return nil }
        
        let channel_array_length = self.count / channelCount
        
        guard channel_array_length > 0 else { return nil }
        
        var channel_array = [Int16](repeating: 0, count: channel_array_length)
        
        for index in 0...channel_array_length-1 {
            let array_index = channelIndex + index * channelCount
            channel_array[index] = self[array_index]
        }
        
        return channel_array
    }
    
    func extract_array_channels(channelCount:Int) -> [[Int16]] {
        
        var channels:[[Int16]] = []
        
        guard channelCount > 0 else { return channels }
        
        for channel_index in 0...channelCount-1 {
            if let channel = self.extract_array_channel(channelIndex: channel_index, channelCount: channelCount) {
                channels.append(channel)
            }
            
        }
        
        return channels
    }
}

class ScaleAudio {
        
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
    
    func readAndScaleAudioSamples(asset:AVAsset, factor:Double, singleChannel:Bool, progress: @escaping (Float, String) -> ()) -> (Int, Int, CMAudioFormatDescription?, [Int16]?)? {
        
        progress(0, "Reading audio:")
        
        var outputSettings:[String : Any] = kAudioReaderSettings
        
        if singleChannel {
            outputSettings[AVNumberOfChannelsKey] = 1 as AnyObject
        }
        
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
        
        if audioReader.startReading() {
            
            while audioReader.status == .reading {
                
                autoreleasepool { () -> Void in
                    
                    if let sampleBuffer = audioReaderOutput.copyNextSampleBuffer(), let bufferSamples = self.extractSamples(sampleBuffer) {
                        
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
        
        let scaledAudioSamples = scaleAudioSamples(audioSamples, factor: factor, progress:progress)
        
        return (bufferSize, channelCount, formatDescription, scaledAudioSamples)
    }
    
    func interleave_arrays(_ arrays:[[Int16]], progress: @escaping (Float, String) -> ()) -> [Int16]? {
                
        progress(0, "Interleaving:")
        
        guard arrays.count > 0 else { return nil }
        
        if arrays.count == 1 {
            return arrays[0]
        }
        
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
                
                if totalElapsed > 1 {
                    totalElapsed = 0
                    let percent = Float(count) / Float(interleaved_length)
                    progress(percent, "Interleaving \(Int(percent * 100))%:")
                }
            }
        }
        
        return interleaved 
    }
    
    func scaleAudioSamples(_ audioSamples:[[Int16]], factor:Double, progress: @escaping (Float, String) -> ()) -> [Int16]? {
                
        var scaledAudioSamplesChannels:[[Int16]] = []
        
        progress(0, "Scaling:")
        
        for (index, audioSamplesChannel) in audioSamples.enumerated() {
            
            let percent = (Float(index+1) / Float(audioSamples.count))
            progress(percent, "Scaling \(Int(percent * 100))%:")
            
            let length = Int(Double(audioSamplesChannel.count) * factor)
            
            scaledAudioSamplesChannels.append(audioSamplesChannel.scaleToD(length: length, smoothly: true)) 
        }
        
        return interleave_arrays(scaledAudioSamplesChannels, progress:progress)
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
    
    func sampleBuffersForSamples(bufferSize:Int, audioSamples:[Int16], channelCount:Int, formatDescription:CMAudioFormatDescription, progress: @escaping (Float, String) -> ()) -> [CMSampleBuffer?] {
        
        progress(0, "Preparing Samples:")
                
        let blockedAudioSamples = audioSamples.blocks(size: bufferSize)
                
        var sampleBuffers:[CMSampleBuffer?] = []
        
        for (index, audioSamples) in blockedAudioSamples.enumerated() {
        
            let percent = (Float(index+1) / Float(blockedAudioSamples.count))
            progress(percent, "Preparing Samples \(Int(percent * 100))%:")
            
            let sampleBuffer = sampleBufferForSamples(audioSamples: audioSamples, channelCount:channelCount, formatDescription: formatDescription)
            
            sampleBuffers.append(sampleBuffer)
        }
        
        return sampleBuffers
    }
    
    func saveSampleBuffersToFile(_ sampleBuffers:[CMSampleBuffer?], formatDescription:CMAudioFormatDescription, destinationURL:URL, progress: @escaping (Float, String) -> (), completion: @escaping (Bool, String?) -> ())  {
        
        progress(0, "Writing Samples:")
                
        let nbrSamples = sampleBuffers.count
        
        guard nbrSamples > 0  else {
            completion(false, "Invalid buffer count.")
            return
        }
        
        do {
            try FileManager.default.removeItem(at: destinationURL)
        } catch _ {}
        
        guard let assetWriter = try? AVAssetWriter(outputURL: destinationURL, fileType: AVFileType.wav) else {
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
                
                let percent = (Float(index) / Float(nbrSamples))
                progress(percent, "Writing Samples \(Int(percent * 100))%:")
                
                if index == nbrSamples {
                    audioWriterInput.markAsFinished()
                    
                    finishWriting()
                }
            }
        }
    }
    
    func scaleAudio(asset:AVAsset, factor:Double, singleChannel:Bool, destinationURL:URL, progress: @escaping (Float, String) -> (), completion: @escaping (Bool, String?) -> ())  {
        
        guard let (bufferSize, channelCount, formatDescription, audioSamples) = readAndScaleAudioSamples(asset: asset, factor: factor, singleChannel: singleChannel, progress:progress) else {
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
        
        let sampleBuffers = sampleBuffersForSamples(bufferSize: bufferSize, audioSamples: audioSamples, channelCount:channelCount, formatDescription: formatDescription, progress:progress)
        
        saveSampleBuffersToFile(sampleBuffers, formatDescription: formatDescription, destinationURL: destinationURL, progress: progress, completion: completion)
    }
}
