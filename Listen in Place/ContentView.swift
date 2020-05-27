import SwiftUI
import AVFoundation

struct ContentView: View {
    var songs = [Song(title: "Click me",
                      artist: "Art"),
                 
                 Song(title: "Some  song",
                      artist: "My Art"),
                 
                 Song(title: "Hello world",
                      artist: "Tom"),
                 
                 Song(title: "Song",
                      artist: "Artist"),
                 Song(title: "Tom",
                      artist: "Nook"),
                 Song(title: "The Ballad of Mona Lisa",
                      artist: "Panic! at the Disco")]
    @EnvironmentObject var player: Player
    var body: some View {
        VStack {
            NavigationView {
                List {
                    ForEach(songs, id: \.self) { song in
                        SongCellView(song: song)
                        
                    }
                }.onAppear {
                    UITableView.appearance()
                        .separatorStyle = .none
                }
                .navigationBarTitle(Text("Song"))
                .navigationBarItems(trailing: DocumentPickerButton(documentTypes: ["public.mp3"],
                                                                   onOpen: self.openSong){
                    Image(systemName: "plus.circle.fill")
                    .resizable()
                } )
            }
            if !self.player.queue.isEmpty {
                GlobalControls()
            } else {
                EmptyView()
            }
        }
        
    }
    
    func openSong (urls: [URL]) -> () {
        print("Reading URLS")
        urls.forEach { url in
            guard url.startAccessingSecurityScopedResource() else {
                print("Failed to open the file")
                return
            }
            print(url)
            defer { url.stopAccessingSecurityScopedResource() }
            
            guard let bookmark = try? url.bookmarkData() else {
                return
            }
            
            let defaults = UserDefaults.standard
            
            var array = defaults.array(forKey: "Songs") as? [Data]
            array?.append(bookmark)
            defaults.set(array, forKey: "Songs")
            
            self.player.song = .AVPlayer(.init(url: url))
        }
    }
}

struct GlobalControls: View {
    @State
    var showPlayer = false
    
    @EnvironmentObject
    var player: Player
    
    var body: some View {
        Button(action: {
            self.showPlayer.toggle()
        }) {
            HStack {
                SongView(song: player.nowPlaying!)
                Spacer()
                MusicControls()
            }.padding()
            
    }
        .background(Color(.secondarySystemBackground))
        .clipped()
        .shadow(radius: 5)
        .sheet(isPresented: self.$showPlayer) {
            MusicView(song: self.player.queue.first!)
                .environmentObject(self.player)
        }
    }
}

struct SongCellView: View {
    @State var showPlayer = false
    
    @EnvironmentObject var player: Player
    
    let song: Song
    var body: some View {
        Button(action: {
            self.showPlayer.toggle()
        }) {
            SongView(song: song)
        }.sheet(isPresented: self.$showPlayer) {
            MusicView(song: self.song)
                .environmentObject(self.player)
        }
    }
}

struct SongView: View {
    let song: Song
    var body: some View {
        HStack {
            
            Image("LP")
                .resizable()
                .renderingMode(.original)
                .frame(width: 40, height: 40, alignment: .leading)
                .shadow(radius: 5)

            VStack {
                Text(song.title)
                    .font(.headline)

                Text(song.artist)
            }.padding(2)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        
        return TestView(view: ContentView())
    }
}

