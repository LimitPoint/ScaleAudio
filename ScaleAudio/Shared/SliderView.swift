//
//  SliderView.swift
//  ScaleAudio
//
//  Read discussion at:
//  http://www.limit-point.com/blog/2022/scale-audio/
//
//  Created by Joseph Pagliaro on 2/12/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import SwiftUI

struct SliderView: View {
    
    @ObservedObject var scaleAudioObservable: ScaleAudioObservable
    
    @State private var isEditing = false
    var body: some View {
        VStack {
            Slider(
                value: $scaleAudioObservable.factor,
                in: 0.1...2
            ) {
                Text("Factor")
            } minimumValueLabel: {
                Text("0.1")
            } maximumValueLabel: {
                Text("2")
            } onEditingChanged: { editing in
                isEditing = editing
            }
            Text(String(format: "%.2f", scaleAudioObservable.factor))
                .foregroundColor(isEditing ? .red : .blue)
        }
        .padding()
        
    }
}

struct SliderView_Previews: PreviewProvider {
    static var previews: some View {
        SliderView(scaleAudioObservable: ScaleAudioObservable())
    }
}
