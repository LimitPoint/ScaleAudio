//
//  FileTableView.swift
//  ScaleAudio
//
//  Created by Joseph Pagliaro on 2/11/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import Foundation
import SwiftUI

struct FileTableViewRowView: View {
    
    var file:File
    
    @ObservedObject var scaleAudioObservable: ScaleAudioObservable
    
    var body: some View {
        HStack {
            Text("\(file.url.lastPathComponent) [\(file.duration)]")
            
            Button("Play", action: {
                scaleAudioObservable.playAudioURL(file.url)
            })
                .buttonStyle(BorderlessButtonStyle()) // need this or tapping one invokes both actions
            
            Button("Scale", action: {
                scaleAudioObservable.scaleAudioURL(url: file.url)
            })
                .buttonStyle(BorderlessButtonStyle())
        }
    }
}

struct FileTableView: View {
    
    @ObservedObject var scaleAudioObservable: ScaleAudioObservable
    
    var body: some View {
        
        if scaleAudioObservable.files.count == 0 {
            Text("No Audio Files")
                .padding()
        }
        else {
#if os(macOS)
                // https://developer.apple.com/documentation/swiftui/list
            List(scaleAudioObservable.files) {
                FileTableViewRowView(file: $0, scaleAudioObservable: scaleAudioObservable)
            }
#else
            NavigationView {
                    // https://developer.apple.com/documentation/swiftui/list
                List(scaleAudioObservable.files) {
                    FileTableViewRowView(file: $0, scaleAudioObservable: scaleAudioObservable)
                }
                .navigationTitle("Audio Files")
                
            }
            .navigationViewStyle(StackNavigationViewStyle()) // otherwise on iPad appears 'collapsed'
#endif
        }
        
    }
}

struct FileTableView_Previews: PreviewProvider {
    static var previews: some View {
        FileTableView(scaleAudioObservable: ScaleAudioObservable())
    }
}
