//
//  ContentView.swift
//  Shared
//
//  Read discussion at:
//  http://www.limit-point.com/blog/2022/scale-audio/
//
//  Created by Joseph Pagliaro on 2/11/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import SwiftUI

let softPink = Color(red: 249.0 / 255.0, green: 182.0 / 255.0, blue: 233.0 / 255.0, opacity:0.9)

struct ContentView: View {
    
    @ObservedObject var scaleAudioObservable: ScaleAudioObservable
    
    var body: some View {
        
        VStack {
            
            HeaderView(scaleAudioObservable: scaleAudioObservable)
            
            FileTableView(scaleAudioObservable: scaleAudioObservable)
            
            SliderView(scaleAudioObservable: scaleAudioObservable)
            
            ToggleView(scaleAudioObservable: scaleAudioObservable)
            
            ActivityView(scaleAudioObservable: scaleAudioObservable)
        }
        .overlay(Group {
            if scaleAudioObservable.isScaling {          
                ProgressView("Scaling...")
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 16).fill(softPink))
            }
        })
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(scaleAudioObservable: ScaleAudioObservable())
    }
}

