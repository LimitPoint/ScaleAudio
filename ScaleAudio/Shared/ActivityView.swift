//
//  ActivityView.swift
//  ScaleAudio
//
//  Read discussion at:
//  http://www.limit-point.com/blog/2022/scale-audio/
//
//  Created by Joseph Pagliaro on 2/11/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import SwiftUI

struct ActivityView: View {
    
    @ObservedObject var scaleAudioObservable: ScaleAudioObservable
    
    var body: some View {
        VStack {
            ProgressView(scaleAudioObservable.progressTitle, value: scaleAudioObservable.progress, total: 1)
                .padding(2)
                .frame(width: 300)
            
            if let audioURL = scaleAudioObservable.scaledAudioURL {
                Button("Play Scaled '\(scaleAudioObservable.filename)'", action: { 
                    scaleAudioObservable.playAudioURL(audioURL)
                }).padding(2)
            }
            else {
                Text("No scaled audio to play.")
                    .padding(2)
            }
        }
        .padding(5)
    }
}

struct ActivityView_Previews: PreviewProvider {
    static var previews: some View {
        ActivityView(scaleAudioObservable: ScaleAudioObservable())
    }
}
