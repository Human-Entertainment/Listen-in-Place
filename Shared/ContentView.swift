import SwiftUI
import SwiftData
import AVFoundation
import CoreData
import Match

var errorSong: Song {
    let song = Song(title: "Couldn't load title", artist: "Cound't load artis")
    return song
}

struct ContentView: View {
    @Environment(\.modelContext)
    private var modelContext
    @Environment(\.horizontalSizeClass)
    private var horizontalSizeClass
    @Environment(\.threadPool)
    private var threadPool
    
    @Environment(Player.self)
    private var player: Player
    
    @State
    private var showSongContext = false
    @State
    private var presentFiles = false
    
    @Query
    private var songs: [Song]
    
    var body: some View {
        
        VStack {
            
            NavigationView {
                List {
                    ForEach(songs) { song in
                        SongCellView(song: song)
                        
                    }
                    .onDelete { indexSet in
                        withAnimation {
                            for index in indexSet {
                                modelContext.delete(songs[index])
                            }
                        }
                    }
                }
                
                .navigationBarTitle(Text("Song"))
                .navigationBarItems(trailing: AddSongButton(presentFiles: $presentFiles))
                
            }
            if self.player.nowPlaying != nil {
                GlobalControls()
                    .frame(width: .none, height: 100, alignment: .bottom)
                    .alignmentGuide(.bottom, computeValue: {d in d[explicit: .bottom]!})
            } else {
                EmptyView()
            }
        }.fileImporter(
        isPresented: $presentFiles,
        allowedContentTypes: [.audio],
        allowsMultipleSelection: true,
        onCompletion: addSongHandler
        )
                    
        
    }
    
    func addSongHandler(result: Result<[URL], Error>?) {
        guard case let .success(urls) = result else { return print("Couldn't open files") }
        
        openSong(urls: urls)
        
    }
    
    func openSong(urls: [URL]) {
        Task {
            self.threadPool.start()
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else {
                    print("Failed to open the file")
                    return
                }
                
                defer {
                    url.stopAccessingSecurityScopedResource()
                }
                guard let newSong = try? await Song.load(url: url, bookmark: url.bookmarkData(), on: self.threadPool) else {
                    continue
                }
                
                withAnimation {
                    modelContext.insert(newSong)
                }
            }
        }
    }
}

struct AddSongButton: View {
    @Binding
    var presentFiles: Bool
    
    var body: some View {
        Button {
            presentFiles = true
        } label: {
            Image(systemName: "plus.circle.fill")
                .resizable()
                .padding()
        }
    }
}


struct GlobalControls: View {
    @State
    var showPlayer = false
    
    @State
    var text: String = "Hello"
    
    @Environment(Player.self)
    var player: Player
    
    var body: some View {
        Button(action: {
            if (self.player.nowPlaying != nil) {
                self.showPlayer.toggle()
            }
        }) {
            HStack {
                SongView(song: player.nowPlaying ?? notPlaying, frame: 60)
                Spacer()
                MusicControls()
            }.padding(5)
            
    }
        .background(Color(.secondarySystemBackground))
        .clipped()
        .sheet(isPresented: self.$showPlayer) {
            MusicView( song: self.player.nowPlaying ?? notPlaying)
                .environmentObject(self.player)
        }
    }
}

struct SongCellView: View {
    
    @Environment(Player.self)
    var player: Player
    
    @State var showAction = false
    
    let song: Song
    var body: some View {
        
        SongView(song: song)
            .onTapGesture {
                try? self.player.play(self.song)
        }
        .onLongPressGesture {
            self.showAction.toggle()
        }
        .actionSheet(isPresented: $showAction){
            ActionSheet(title: "Hi", message: "Hello", buttons: [
                .default("Play last", action: { self.player.addToQueue(self.song) }),
                .cancel { self.showAction.toggle() }
            ])
        }
    }
    
}

extension Text: ExpressibleByStringLiteral {
    public typealias StringLiteralType = String
    
    public init(stringLiteral value: String) {
        self.init(value)
    }
}

var notPlaying: Song {
    let song = Song(title: "Not Playing", artist: "Not Playing")
    return song
}

struct SongView: View {
    init(song: Song, frame: Int? = nil) {
        self.frame = frame ?? 40
        self.song = song
    }
    
    var frame: Int
    let song: Song
    var body: some View {
        HStack {
            
            Image(uiImage: song.coverImage)
                .resizable()
                .renderingMode(.original)
                .frame(width: CGFloat(self.frame), height: CGFloat(self.frame), alignment: .leading)
                .cornerRadius(5)
                .shadow(radius: 2)
                

            VStack (alignment: .leading) {
                Text(song.title)
                
            }.padding(2)
        }
    }
}

// TODO: Fix this
/*
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        
        return TestView(view: ContentView()
                            .environmentObject(Player.shared(persistentContainer)))
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
