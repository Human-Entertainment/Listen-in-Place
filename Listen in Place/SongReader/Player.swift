import Foundation
import AVFoundation
import UIKit
import MediaPlayer
import CoreData
import Combine

typealias Byte = UInt8

final class Player: ObservableObject, Subscriber {
    private var subscription: Subscription? = nil
    func receive(subscription: Subscription) {
        self.subscription = subscription
    }
    
    func receive(_ input: Song) -> Subscribers.Demand {
        if !all.contains(input) {
            all.append(input)
        }
        return Subscribers.Demand.unlimited
    }
    
    func receive(completion: Subscribers.Completion<SongError>) {
        
    }
    
    
    typealias Input = Song
    
    typealias Failure = SongError
    
    
    private var player: PlayerEnum
    private var _avPlayer: AVPlayer?
    @Published var progress: Float = 0.0
    @Published var isPlaying = false
    private var url: URL? = nil
    private var audioQueue = DispatchQueue.init(label: "audio")
    @Published var nowPlaying: Song? = nil
    
    // MARK: Access
    
    @Published var all = [Song]()
    
    func add(url: URL) {
        guard let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext else {
            return
        }
        
        let newSong = Songs(context: context)
        newSong.bookmark = try? url.bookmarkData()
        // TODO: Fix this stuff
        
        try? SongPublisher().load(bookmark: newSong.bookmark).receive(subscriber: self)
        
        try? context.save()
    }
    
    // MARK: Setup
    
    init() {
        player = .none
        // Setup mediacenter controls
        setupRemoteTransportControls()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(avPlayerDidFinishPlaying(note:)),
                                               name: .AVPlayerItemDidPlayToEndTime, object: nil)
        
        if let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: "Songs")
            
            do {
                let result = try context.fetch(request)
                
                (result as! [NSManagedObject]).forEach { result in
                    guard let bookmark = result.value(forKey: "bookmark") as? Data else { return }
                    // TODO: Fix
                        
                    try? SongPublisher().load(bookmark: bookmark).receive(subscriber: self)
                }
            } catch {
                
            }
        }
        
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
        
        pause()
        player = .AVPlayer(.init(url: url), url)
        
        switch player {
            case .AVPlayer(_, let url):
                self.url = url
            default:
                break
        }
        nowPlaying = song
        
        // TODO: Empty queue and add this song to queue
        
        play()
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
        
        // TODO: Remove first item in queue
        
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
        switch player {
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
