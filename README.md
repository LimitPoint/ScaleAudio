![ScaleAudio](http://www.limit-point.com/assets/images/ScaleAudio.jpg)
# ScaleAudio.swift
## Scales all channels in time domain of an audio file into another multi-channel WAV audio file

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
2. Create an array of sample buffers [[CMSampleBuffer]] for the array of scaled audio samples
3. Write the scaled sample buffers in [[CMSampleBuffer]] to a file

The top level method that implements all of this, and is employed by the `ScaleAudioObservable` is: 

```swift
func scaleAudio(asset:AVAsset, factor:Double, destinationURL:URL, progress: @escaping (Float, String) -> (), completion: @escaping (Bool, String?) -> ())
```

[App]: https://developer.apple.com/documentation/swiftui/app
[ObservableObject]: https://developer.apple.com/documentation/combine/observableobject
[AVFoundation]: https://developer.apple.com/documentation/avfoundation/
[SwiftUI]: https://developer.apple.com/tutorials/swiftui
[CMSampleBuffer]: https://developer.apple.com/documentation/coremedia/cmsamplebuffer
