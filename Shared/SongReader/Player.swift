import Foundation
import AVFoundation
import MediaPlayer
import CoreData
import Combine
import NIO
import NIOTransportServices

typealias Byte = UInt8

final class Player: ObservableObject {
    private let container: NSPersistentContainer
    
    private var player: PlayerEnum
    @Published var progress: Float = 0.0
    @Published var isPlaying = false
    private var url: URL? = nil
    @Published var nowPlaying: Song? = nil
    
    // MARK: - Access
    
    @Published var all = [Song]()
    var cancellable = [AnyCancellable]()

    func add(url: URL) {
        container.performBackgroundTask { [self] context in
            do {
                let newSong = Songs(context: context)
                let bookmark = try url.bookmarkData()
                newSong.bookmark = bookmark
                // TODO: Fix this stuff
                
                fetchSong(url: url, bookmark: bookmark)
                
                
            } catch {
                print("An error occured: \(error)")
            }
            
            try? context.save()
            }
    }

    func fetchSong(url: URL, bookmark: Data) {
        try? SongPublisher(threadPool: .init(numberOfThreads: 1))
            .load(url: url, bookmark: bookmark)
            .print("Song")
            .sink {
                switch $0 {
                    case .failure(let songError):
                        print("Read error with \(songError)")
                        break
                    case .finished:
                        print("Got all the things")
                        break
                    
                }
                
            } receiveValue: { song in
                DispatchQueue.main.async {
                    //if !self.all.contains(song) {
                        self.all.append(song)
                    //}
                }
            }.store(in: &cancellable)
    }
    
    // MARK: - Setup
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    private init(container: NSPersistentContainer) {
        self.container = container
        player = .none
        // Setup mediacenter controls
        setupRemoteTransportControls()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(avPlayerDidFinishPlaying(note:)),
                                               name: .AVPlayerItemDidPlayToEndTime, object: nil)
        
        asyncInit()
        
    }
    
    public static let shared: (NSPersistentContainer) -> (Player) = { Player(container: $0) }
    
    func asyncInit() {
        container.performBackgroundTask { context in
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: "Songs")
            
            do {
                // TODO: - Fix this
                guard let result = try context.fetch(request) as? [NSManagedObject] else { return }
                
                result.forEach { [weak self] result in
                    guard let bookmark = result.value(forKey: "bookmark") as? Data else { return }
                    
                    do {
                        
                        var isStale = false
                        let url = try URL(
                            resolvingBookmarkData: bookmark,
                            options: .withoutUI,
                            bookmarkDataIsStale: &isStale
                        )
                        
                        self?.fetchSong(url: url, bookmark: bookmark)
                        
                    } catch {
                        print("Couldn't get URL from database because: \(error)")
                    }
                }
            } catch {
                // TODO: Couldn't get file UI
                print("Couldn't retrieve file in CoreData with error \(error)")
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
    

    // MARK: - Queue
    @Published
    private(set) var sharedQueue = [Song]()
    
    func addToQueue(_ song: Song) {
        sharedQueue.append(song)
    }
    
    func nextSong() -> Song? {
        if sharedQueue.count > 0 {
            return sharedQueue.removeFirst()
        } else {
            return nil
        }
    }

    // MARK: - Controls
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
    
    let isPlayingQueue = DispatchQueue(label: "IsPlayingListerner")
    let isPlayingDispatchGroup = DispatchGroup()
    
    func play() {
        // Set this first, as to not break the async queue
        isPlaying = true
        switch player {
        case .AVPlayer(let player, _):
            player.play()
            let interval = 1.0 / 240
            token = player.addPeriodicTimeObserver(
                forInterval: .init(seconds: interval, preferredTimescale: CMTimeScale(NSEC_PER_SEC)),
                queue: nil,
                using: {time in
                    let seconds = time.seconds
                    let duration = player.currentItem?.duration.seconds ?? 0
                    let percent = seconds / duration
                    self.progress = Float( percent )
                    self.setupNowPlaying(song: self.nowPlaying!, elapsed: seconds, total: duration)
                })
            
            NotificationCenter
                .default
                .addObserver(
                    self,
                    selector: #selector(handleInterruption),
                    name: AVAudioSession.interruptionNotification,
                    object: nil)
                
            isPlayingQueue.async {
                while self.isPlaying {
                    if player.timeControlStatus == .paused {
                        DispatchQueue.main.async {
                            self.isPlaying = false
                        }
                    }
                }
            }
            break
        default:
            isPlaying = false
            break
        }
    }
    
    @objc func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
            let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
                return
        }
        
        // Switch over the interruption type.
        switch type {
            
            case .began:
            // An interruption began. Update the UI as needed.
                self.isPlaying = false
            case .ended:
                // An interruption ended. Resume playback, if appropriate.
                
                guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    // Interruption ended. Playback should resume.
                    self.play()
                } else {
                    // Interruption ended. Playback should not resume.
            }
            
            default: ()
        }
    }
    
    @objc func avPlayerDidFinishPlaying(note: NSNotification) {
        guard case let PlayerEnum.AVPlayer(player, _) = self.player else { return }
        if let token = token {
            player.removeTimeObserver(token)
        }
        
        playNext()
    }
    
    func playNext() {
        pause()
        self.player = .none
        isPlaying = false
        if let nextSong = nextSong() {
            try? play(nextSong)
        }
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
