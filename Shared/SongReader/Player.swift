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
    
    private var player: AVPlayer?
    
    @Published var progress: Float = 0.0
    @Published var isPlaying = false
    private var url: URL? = nil
    @Published var nowPlaying: Song? = nil
    
    // MARK: - Access
    
    @Published var all = [Song]()
    var cancellable = [AnyCancellable]()
    
    private var threadPool = NIOThreadPool(numberOfThreads: 1)

    func add(url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            print("Failed to open the file")
            return
        }
        
        container.performBackgroundTask { [self] context in
            do {
                let newSong = Songs(context: context)
                let bookmark = try url.bookmarkData()
                newSong.bookmark = bookmark
                // TODO: Fix this stuff
                
                fetchSong(url: url,
                          bookmark: bookmark,
                          threadPool: self.threadPool,
                          on: NIOTSEventLoopGroup().next())
                
                
            } catch {
                print("An error occured: \(error)")
            }
            
            try? context.save()
        }
    }

    func fetchSong(url: URL,
                   bookmark: Data,
                   threadPool: NIOThreadPool?,
                   on eventloop: EventLoop) {
        guard let threadPool = threadPool else {
            print("No threadpool")
            return
        }
        try? SongPublisher(threadPool: threadPool,
                           on: eventloop)
            .load(url: url, bookmark: bookmark)
            .print("Song")
            .sink {
                guard case .failure(let songError) = $0 else { return }
                print(songError)
            } receiveValue: { song in
                DispatchQueue.main.async {
                    if !self.all.contains(song) {
                        self.all.append(song)
                    }
                    url.stopAccessingSecurityScopedResource()
                }
            }.store(in: &cancellable)
    }
    
    // MARK: - Setup
    private init(container: NSPersistentContainer) {
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // Set the audio session category, mode, and options.
            try audioSession.setCategory(.playback, mode: .default, options: [])
        } catch {
            print("Failed to set audio session category.")
        }
        
        self.container = container
        player = nil
        // Setup mediacenter controls
        setupRemoteTransportControls()
        NotificationCenter.default
            .publisher(for: .AVPlayerItemDidPlayToEndTime)
            .sink(receiveValue: avPlayerDidFinishPlaying)
            .store(in: &cancellable)
        
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
                        self?.fetchSong(
                            url: url,
                            bookmark: bookmark,
                            threadPool: self?.threadPool,
                            on: NIOTSEventLoopGroup().next()
                        )
                        
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
        
        commandCenter.changePlaybackPositionCommand.addTarget { [unowned self] remoteEvent in
            guard let event = remoteEvent as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
    
            //let duration = player.currentItem?.duration.seconds ?? 0
            let seek = event.positionTime
            guard let player = player else { return .noActionableNowPlayingItem }
            player.seek(to: CMTime(seconds: seek, preferredTimescale: CMTimeScale(1000)))
            return .success
            
            
        }
        
        commandCenter.nextTrackCommand.addTarget { [unowned self] remoteEvent in
            guard self.nextSong() != nil else { return .noSuchContent }
            self.playNext()
            return .success
        }
        
        
        commandCenter.previousTrackCommand.addTarget { _ in
            return .commandFailed
        }
        
        /*
        commandCenter.bookmarkCommand.addTarget { [unowned self] event in
            .commandFailed
        }
*/
    }
    
    func setupNowPlaying(song: Song, elapsed: Double, total: Double) {
        // Define Now Playing Info
        var nowPlayingInfo = [String : Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = song.title
        
        nowPlayingInfo[MPMediaItemPropertyArtist] = song.artist
        
        nowPlayingInfo[MPMediaItemPropertyArtwork] =
            MPMediaItemArtwork(boundsSize: song.coverImage.size) { size in
                return song.coverImage
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
        player = .init(url: url)
        
        self.url = url
        nowPlaying = song
        
        // TODO: Empty queue and add this song to queue
        
        play()
    }
    
    var timerObserver: Any?
    
    func addPeriodicTimeObserver()
    {
            
        let interval = 1.0 / 240
        timerObserver = player?.addPeriodicTimeObserver(
                forInterval: .init(seconds: interval, preferredTimescale: CMTimeScale(NSEC_PER_SEC)),
                queue: nil,
                using: {time in
                    let seconds = time.seconds
                    let duration = self.player?.currentItem?.duration.seconds ?? 0
                    let percent = seconds / duration
                    self.progress = Float( percent )
                    self.setupNowPlaying(song: self.nowPlaying!, elapsed: seconds, total: duration)
                })
    }
    
    func removePeriodicTimeObserver()
    {
        guard let token = timerObserver else {
            return
        }
        player?.removeTimeObserver(token)
        
        timerObserver = nil
    }
    
    func play() {
        guard let player = player else {
            return
        }
        player.publisher(for: \.timeControlStatus)
            .sink { controlStatus in
                switch controlStatus {
                    case .paused: self.isPlaying = false
                    case .playing: self.isPlaying = true
                    case .waitingToPlayAtSpecifiedRate:
                        self.isPlaying = false
                    @unknown default:
                        self.isPlaying = false
                }
            }.store(in: &cancellable)
        player.actionAtItemEnd = .advance
        player.play()
        
        self.addPeriodicTimeObserver()
        
        NotificationCenter
            .default
            .publisher(for: AVAudioSession.interruptionNotification)
            .sink(receiveValue: handleInterruption)
            .store(in: &cancellable)
            
        
        isPlaying = true
           
    }
    
    func handleInterruption(notification: Notification) {
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
    
    func avPlayerDidFinishPlaying(note: Notification) {
        self.removePeriodicTimeObserver()
        
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
       player?.pause()
    }
    
    func seek(to: Float){
                
        let duration = player?.currentItem?.duration.seconds ?? 0
        let percent = Double(to) * duration
        player?.seek(to: .init(seconds: percent, preferredTimescale: CMTimeScale(10)))
           
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
