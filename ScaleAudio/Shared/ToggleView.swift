//
//  ToggleView.swift
//  ScaleAudio
//
//  Read discussion at:
//  http://www.limit-point.com/blog/2022/scale-audio/
//
//  Created by Joseph Pagliaro on 2/15/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import SwiftUI

struct ToggleView: View {
    
    @ObservedObject var scaleAudioObservable: ScaleAudioObservable
    
    var body: some View {
        Toggle(isOn: $scaleAudioObservable.singleChannel) {
            Text("Single Channel")
        }
        .padding()
    }
}

struct ToggleView_Previews: PreviewProvider {
    static var previews: some View {
        ToggleView(scaleAudioObservable: ScaleAudioObservable())
    }
}
