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
    @EnvironmentObject
    var player: Player
    let song: Song
    
    @State
    var progressValue: Float = 0.5
    @State
    var isPlaying = false
    
    var body: some View {
        VStack {
            Spacer()
            Text(song.title)

            ProgressBar(value: self.$player.progress).frame(height: 20)
            MusicControls()
            
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
            .environmentObject(Player())
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
                
                Rectangle().frame(width: self.min(geometry: geometry),
                                  height: geometry.size.height)
                    .foregroundColor(.accentColor)
                    .animation(.linear)
            }.cornerRadius(45.0)
        }
    }
    func min(geometry: GeometryProxy) -> CGFloat {
        print(self.value)
        return Swift.min(CGFloat(self.value)*geometry.size.width, geometry.size.width)
    }
}

struct PlayButton: View {
    @EnvironmentObject
    var player: Player
    var body: some View {
        Button(action: {
            self.player.toggle()
        }) {
            if !player.isPlaying {
                Image(systemName: "play.fill")
                    .resizable()
            } else {
                Image(systemName: "pause.fill")
                    .resizable()
            }
        }.frame(width: 40, height: 40)
    }
}

struct MusicControls: View {
    
    var body: some View {
        PlayButton()
    }
}
