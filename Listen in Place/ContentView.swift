import SwiftUI
import AVFoundation
import CoreData

let errorSong = Song(title: "Couldn't load title", artist: "Cound't load artis")

struct ContentView: View {
    @Environment(\.managedObjectContext)
    var moc
    /*
    @FetchRequest(entity: Songs.entity(),
                  sortDescriptors: [])
    var songs: FetchedResults<Songs>
    */
    @EnvironmentObject
    var player: Player
    var body: some View {
        VStack {
            NavigationView {
                List {
                    ForEach(player.all, id: \.self) { song in
                        SongCellView(song: song)
                    }
                }.onAppear {
                    UITableView.appearance()
                        .separatorStyle = .none
                }
                .navigationBarTitle(Text("Song"))
                .navigationBarItems(trailing: DocumentPickerButton(documentTypes: ["public.mp3", "org.xiph.flac"],
                                                                   onOpen: self.openSong){
                    Image(systemName: "plus.circle.fill")
                        .resizable()
                        .padding()
                } )
            }
            if self.player.nowPlaying != nil {
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
            
            self.player.add(url: url)
        }
    }
}

struct GlobalControls: View {
    @State
    var showPlayer = false
    
    @State
    var text: String = "Hello"
    
    @EnvironmentObject
    var player: Player
    
    var body: some View {
        Button(action: {
            if (self.player.nowPlaying != nil) {
                self.showPlayer.toggle()
            }
        }) {
            HStack {
                SongView(song: player.nowPlaying ?? notPlaying)
                Spacer()
                MusicControls()
            }.padding()
            
    }
        .background(Color(.secondarySystemBackground))
        .clipped()
        .shadow(radius: 5)
        .sheet(isPresented: self.$showPlayer) {
            MusicView(song: self.player.nowPlaying ?? notPlaying)
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
            try? self.player.play(self.song)
        }) {
            SongView(song: song)
        }.sheet(isPresented: self.$showPlayer) {
            MusicView(song: self.song)
                .environmentObject(self.player)
        }
    }
}

let notPlaying = Song(title: "Not Playing", artist: "Not Playing")

struct SongView: View {
    let song: Song
    var body: some View {
        HStack {
            
            Image(uiImage: song.cover)
                .resizable()
                .renderingMode(.original)
                .frame(width: 40, height: 40, alignment: .leading)
                .shadow(radius: 5)

            VStack (alignment: .leading) {
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

