![ScaleAudio](http://www.limit-point.com/assets/images/ScaleAudio.jpg)
# ScaleAudio.swift
## Scales all channels in time domain of an audio file into another multi-channel audio file

Learn more about scaling audio files from our [in-depth blog post](https://www.limit-point.com/blog/2022/scale-audio).

The associated Xcode project implements a [SwiftUI] app for macOS and iOS that presents a list of audio files included in the bundle resources subdirectory 'Audio Files'.

Add your own audio files or use the sample set provided. 

Each file in the list has an adjacent button to either play or scale the audio.

Select the scale factor from a slider.

## Classes

The project is comprised of:

1. The [App] (`ScaleAudioApp`) that displays a list of audio files in the project.
2. And an [ObservableObject] (`ScaleAudioObservable`) that manages the user interaction to scale and play audio files in the list.
3. The [AVFoundation] code (`ScaleAudio`) that reads, scales and writes audio files.

### ScaleAudio

Scaling audio is performed in 3 steps using [AVFoundation]:

1. Read the audio samples of all channels of an audio file, scale all and interleave into an `Array` of `[Int16]`
2. Create an array of sample buffers [[CMSampleBuffer]] for the array of interleaved scaled audio samples
3. Write the scaled sample buffers in [[CMSampleBuffer]] to a file

The top level method that implements all of this, and is employed by the `ScaleAudioObservable` is: 

```swift
func scaleAudio(asset:AVAsset, factor:Double, singleChannel:Bool, destinationURL:URL, avFileType:AVFileType, progress:((Float, String) -> ())? = nil, completion: @escaping (Bool, String?) -> ())
```
Arguments:

1. **asset:AVAsset** - The [AVAsset] for the audio file to be scaled.

2. **factor:Double** - A scale factor < 1 slows down the audio, a factor > 1 speeds it up. For example if the audio is originally 10 seconds long and the scale factor is 2 then the scaled audio will be 20 seconds long. If factor is 0.5 then scaled audio will be 5 seconds long. 

3. **singleChannel:Bool** - The [AVAssetReader] that reads the file can deliver the audio data interleaved with alternating samples from each channel (singleChannel = false) or as a single merged channel (singleChannel = true). 

4. **destinationURL:URL** - A [URL] that specifies the location for the output file. The extension chosen for this URL should be compatible with the next argument for file type. 

5. **avFileType:AVFileType** - An [AVFileType] for the desired file type that should be compatible with the previous argument for file extension.

6. **progress** - An optional handler that is periodically executed to send progress messages and values.

7. **completion** - A handler that is executed when the operation has completed to send a message of success or not.


[App]: https://developer.apple.com/documentation/swiftui/app
[ObservableObject]: https://developer.apple.com/documentation/combine/observableobject
[AVFoundation]: https://developer.apple.com/documentation/avfoundation/
[SwiftUI]: https://developer.apple.com/tutorials/swiftui
[CMSampleBuffer]: https://developer.apple.com/documentation/coremedia/cmsamplebuffer
[AVAsset]: https://developer.apple.com/documentation/avfoundation/avasset
[AVAssetReader]: https://developer.apple.com/documentation/avfoundation/AVAssetReader
[AVFileType]: https://developer.apple.com/documentation/avfoundation/avfiletype
[URL]: https://developer.apple.com/documentation/foundation/url
