//
//  MusicView.swift
//  Listen in Place
//
//  Created by Bastian Inuk Christensen on 23/05/2020.
//  Copyright © 2020 Bastian Inuk Christensen. All rights reserved.
//

import SwiftUI
import Combine

struct MusicView: View {
//    @ObservedObject
    //var player: Player
    let song: Song
    
    @State
    var progressValue: Float = 0.5
    @State
    var isPlaying = false
    
    var body: some View {
        VStack {
            Spacer()
            Text(song.title)
            
            
            ProgressBar(value: $progressValue).frame(height: 20)
            PlayButton(isPlaying: isPlaying)
            
            Spacer()
            
            AirPlayButton()
                .frame(width: 40,
                       height: 40,
                       alignment: .center)
        }.padding()
    }
}

struct MusicView_Previews: PreviewProvider {
    static var previews: some View {
        TestView(view: MusicView(song: Song(title: "Song", artist: "Artist")) )
    }
}

struct ProgressBar: View {
    @Binding var value: Float
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle().frame(width: geometry.size.width,
                                  height: geometry.size.height)
                    .opacity(0.3)
                    .foregroundColor(Color(.systemTeal))
                
                Rectangle().frame(width: min(CGFloat(self.value)*geometry.size.width, geometry.size.width),
                                  height: geometry.size.height)
                    .foregroundColor(.accentColor)
                    .animation(.linear)
            }.cornerRadius(45.0)
        }
    }
}

struct PlayButton: View {
    @State var isPlaying: Bool
    var body: some View {
        Button(action: {
            self.isPlaying.toggle()
        }) {
            if !isPlaying {
                Image(systemName: "livephoto.play")
                    .resizable()
            } else {
                Image(systemName: "icloud.circle.fill")
                    .resizable()
            }
        }.frame(width: 50, height: 50)
    }
}
