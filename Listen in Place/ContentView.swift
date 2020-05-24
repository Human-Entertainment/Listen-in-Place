//
//  ContentView.swift
//  Listen in Place
//
//  Created by Bastian Inuk Christensen on 23/05/2020.
//  Copyright © 2020 Bastian Inuk Christensen. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    var songs = [Song(title: "Click me",
                      artist: "Art"),
                 
                 Song(title: "Some  song",
                      artist: "My Art"),
                 
                 Song(title: "Hello world",
                      artist: "Tom"),
                 
                 Song(title: "Song",
                      artist: "Artist")]
    
    var body: some View {
        NavigationView {
            List {
                ForEach(songs, id: \.self) { song in
                    SongCellView(song: song)
                    
                }
            }.onAppear {
                UITableView.appearance()
                    .separatorStyle = .none
            }
            .navigationBarTitle("Songs")
            
        }.accentColor(.orange)
    }
}

struct SongCellView: View {
    @State var showPlayer = false
    let song: Song
    var body: some View {
        Button(action: { self.showPlayer.toggle() }) {
            HStack {
                Image("LP")
                    .resizable()
                    .frame(width: 40, height: 40, alignment: .leading)
                    .shadow(radius: 5)
                    //.colorInvert()

                VStack {
                    Text(song.title)
                        .font(.headline)

                    Text(song.artist)
                }.padding(2)
            }
        }.sheet(isPresented: self.$showPlayer) {
            MusicView(song: self.song)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        TestView(view: ContentView())
    }
}
