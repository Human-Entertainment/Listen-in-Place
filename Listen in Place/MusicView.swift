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

            Slider(value: Binding( get: {self.player.progress},
                                   set: self.player.seek))
                
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
