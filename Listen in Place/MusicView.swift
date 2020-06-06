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

struct MusicView_Previews: PreviewProvider {
    static var previews: some View {
        MusicView(song: errorSong)
    }
}
