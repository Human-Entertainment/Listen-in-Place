import Foundation
import AVFoundation
import UIKit
import MediaPlayer

typealias Byte = UInt8

struct Song: Hashable {
    let title: String
    let artist: String
    let lyrics: String?
    let cover: UIImage
    let album: String?
    let bookmark: Data?
    init(title: String, artist: String, lyrics: String? = nil, album: String? = nil, cover: UIImage? = nil, bookmark: Data? = nil) {
        self.title = title
        self.artist = artist
        self.lyrics = lyrics
        self.album = album
        self.cover = cover ?? UIImage(named: "LP")!
        self.bookmark = bookmark
    }
    
    init(bookmark: Data) throws {
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: bookmark,
            options: .withoutUI,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
            )
        let player: PlayerEnum = .AVPlayer(.init(url: url), url)
        
        self = player.getSong()
    }
}

final class Player: ObservableObject {
    
    private var player: PlayerEnum
    private var _avPlayer: AVPlayer?
    @Published var progress: Float = 0.0
    @Published var isPlaying = false
    private var url: URL? = nil
    private var audioQueue = DispatchQueue.init(label: "audio")
    var nowPlaying: Song? {
        queue.first
    }
    
    // MARK: Access
    
    var queue: [Song] = []
    private let songKey = "All songs"
    
    @Published var all: [Song] = [Song]()
    
    var song: PlayerEnum {
        set(song) {
            pause()
            player = song
            
            switch song {
                case .AVPlayer(_, let url):
                    self.url = url
                default:
                    break
            }
            let currentSong = song.getSong()
            queue.removeAll(keepingCapacity: false)
            queue.append(currentSong)
            play()
            
            
            if let bookmark = currentSong.bookmark {
                let defaults = UserDefaults.standard
                var array = defaults.array(forKey: songKey) as? [Data] ?? [Data]()
                if !array.contains(bookmark) {
                    array.append(bookmark)
                    defaults.set(array, forKey: songKey)
                }
            }
        }
        
        get {
            player
        }
    }
    
    // MARK: Setup
    
    init() {
        player = .none
        setupRemoteTransportControls()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(avPlayerDidFinishPlaying(note:)),
                                               name: .AVPlayerItemDidPlayToEndTime, object: nil)
        let defaults = UserDefaults.standard
        
        let array = defaults.array(forKey: songKey) as? [Data]
        
        all = array?.compactMap { try? Song(bookmark: $0) } ?? [Song]()
    }
    
    func setupRemoteTransportControls() {
        // Get the shared MPRemoteCommandCenter
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Add handler for Play Command
        commandCenter.playCommand.addTarget { [unowned self] event in
            self.play()
            return .success
        }
        
        // Add handler for Pause Command
        commandCenter.pauseCommand.addTarget { [unowned self] event in
            self.pause()
            return .success
        }
    }
    
    func setupNowPlaying(song: Song, elapsed: Double, total: Double) {
        // Define Now Playing Info
        var nowPlayingInfo = [String : Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = song.title
        
        nowPlayingInfo[MPMediaItemPropertyArtist] = song.artist
        
        nowPlayingInfo[MPMediaItemPropertyArtwork] =
            MPMediaItemArtwork(boundsSize: song.cover.size) { size in
                return song.cover
        }
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = total
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 1
        
        // Set the metadata
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    enum SongError: Error {
        case noBookmark
    }
    // MARK: controls
    func play(_ song: Song) throws {
        guard let bookmark = song.bookmark else { throw SongError.noBookmark }
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: bookmark,
            options: .withoutUI,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        
        self.song = .AVPlayer(.init(url: url), url)
    }
    
    var token: Any?
    
    func play() {
        switch player {
        case .AVPlayer(let player, _):
            player.play()
            let interval = 1.0/240
            token = player.addPeriodicTimeObserver(forInterval: .init(seconds: interval, preferredTimescale: CMTimeScale(NSEC_PER_SEC)),
                                                   queue: nil,
                                                   using: {time in
                                                    let seconds = time.seconds
                                                    let duration = player.currentItem?.duration.seconds ?? 0
                                                    let percent = seconds / duration
                                                    self.progress = Float( percent )
                                                    self.setupNowPlaying(song: self.nowPlaying!, elapsed: seconds, total: duration)
            })
            
        default:
            break
        }
        isPlaying = true
    }
    
    @objc func avPlayerDidFinishPlaying(note: NSNotification) {
        guard case let PlayerEnum.AVPlayer(player, _) = self.player else { return }
        if let token = token {
            player.removeTimeObserver(token)
        }
        
        queue.removeFirst()
        self.player = .none
        isPlaying = false
        
    }
    
    
    
    func pause() {
        switch player {
        case .AVPlayer(let player, _):
            player.pause()
            
        default:
            break
        }
    }
    
    func seek(to: Float){
        switch song {
            case .AVPlayer(let player, _):
                
                let duration = player.currentItem?.duration.seconds ?? 0
                let percent = Double(to) * duration
                player.seek(to: .init(seconds: percent, preferredTimescale: CMTimeScale(10)))
            default:
                break
        }
    }
    
    func toggle() {
        if isPlaying {
            pause()
            isPlaying = false
        } else {
            play()
            isPlaying = true
        }
    }
}
