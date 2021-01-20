import SwiftUI
import Combine

struct MusicView: View {
    @EnvironmentObject
    var player: Player
    let song: Song
    
    @State
    var showQueue = false
    
    var hasQueue: Color {
        if !player.sharedQueue.isEmpty {
            return .accentColor
        } else {
            return .gray
        }
    }
    
    var body: some View {
        VStack {
            
            
            if showQueue {
                
                NavigationView {
                
                
                List {
                    ForEach (player.sharedQueue, id: \.self) { song in
                        SongCellView(song: song)
                    }
                }
                /*
                // TODO: fix seperator style
                .onAppear {
                    UITableView.appearance()
                        .separatorStyle = .none
                }
                    
                .navigationBarTitle(Text("Queue"))
 */
                }
            } else {
                Spacer()
                
                SwiftUI.Image(uiImage: song.coverImage)
                    .resizable()
                    .cornerRadius(10)
                    .shadow(radius: 10)
                    .padding()
                    .aspectRatio(contentMode: .fit)

                Text(song.title)

                Slider(value: Binding( get: {self.player.progress},
                                       set: self.player.seek))
                    
                MusicControls()
                
                Spacer()
            }
            HStack {
                
                //Image(systemName: "square.and.arrow.up")
                
                Spacer()
                
                AirPlayButton()
                    .frame(width: 40,
                           height: 40,
                           alignment: .center)
                    .alignmentGuide(HorizontalAlignment.center, computeValue: {d in d[HorizontalAlignment.center]})
                
                Spacer()
                
                Button ( action: { self.showQueue.toggle() } ) {
                    Image(systemName: "music.note.list")
                    .accentColor(hasQueue)
                    
                }
            }
        }.padding()
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

struct NextButton: View {
    @EnvironmentObject
    var player: Player
    
    var body: some View {
        Group {
        if self.player.sharedQueue > 0 {
            Button(action: {
                self.player.playNext()
            }) {
                Image(systemName: "forward.fill")
                    .resizable()
            }
        } else {
            Image(systemName: "forward.fill")
            .resizable()
                .foregroundColor(Color(.systemGray))
            
            }
            
        }.frame(width: 40, height: 40)
        
    }
}

struct MusicControls: View {
    
    var body: some View {
        HStack {
            PlayButton()
            NextButton()
        }
    }
}

// TODO: Fix this
/*
struct MusicView_Previews: PreviewProvider {
    static var previews: some View {
        MusicView(song: errorSong)
            .environmentObject(Player.shared(self.persistentCointer))
    }
    
    var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "Songs")
        container.loadPersistentStores { description, error in
            if let error = error {
                // Add your error UI here
                fatalError("Unable to load conatainer with \(error)")
            }
            print(description)
        }
        print("Making persistant container")
        return container
    }()
}
*/
