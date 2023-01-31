import Foundation
import AVFoundation
import MediaPlayer
import CoreData
import Combine
import NIO
import NIOTransportServices
import OrderedCollections

typealias Byte = UInt8

final class Player: ObservableObject {
    private let container: NSPersistentContainer
    
    private var player: AVPlayer?
    
    @Published var progress: Float = 0.0
    @Published var isPlaying = false
    private var url: URL? = nil
    @Published var nowPlaying: Song? = nil
    
    // MARK: - Access
    @Published var all = OrderedSet<Song>()
    var cancellable = [AnyCancellable]()
    
    private var threadPool = NIOThreadPool(numberOfThreads: 1)

    func add(url: URL) async throws {
        guard url.startAccessingSecurityScopedResource() else {
            print("Failed to open the file")
            return
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        let context = container.newBackgroundContext()
        
        guard let bookmark = (try? await context.perform {
            let newSong = Songs(context: context)
            // TODO: Fix this stuff
            let bookmark = try url.bookmarkData()
            newSong.bookmark = bookmark
            
            return bookmark
        }) else {
            print("Failed to save the bookmark")
            return
        }
            
        await fetchSong(url: url, bookmark: bookmark)
                
        print("Saving")
        try? context.save()
    }

    func remove(at index: Int)
    {
        let song = self.all.remove(at: index)
        container.performBackgroundTask { context in
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: "Songs")
            
            do {
                // TODO: - Fix this
                (try context.fetch(request) as? [NSManagedObject])?
                    .filter { $0.value(forKey: "bookmark") as? Data == song.bookmark }
                    .forEach {
                        $0.managedObjectContext?.delete($0)
                        do {
                            try $0.managedObjectContext?.save()
                            print("Deleted \(song.title)")
                        } catch {
                            print("Couldn't delete \(song.title) because \(error)")
                        }
                    }
                
            } catch {
                print("Error \(error) orccured")
            }
        }
    }
    
    func fetchSong(url: URL, bookmark: Data) async {

        threadPool.start()
        guard let song = try? await Song
            .load(url: url, bookmark: bookmark, on: threadPool) else {
            return
        }
        
        print("Like for real fore real")
        await MainActor.run {
            all.append(song)
            return
        }
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
        
        Task {
            try! await asyncInit()
        }
    }
    
    public static let shared: (NSPersistentContainer) -> (Player) = { Player(container: $0) }
    
    func asyncInit() async throws {
        let context = container.newBackgroundContext()
        let request = try await context.perform {
            let request = Songs.fetchRequest()
            request.resultType = .managedObjectResultType
            return try request.execute()
        }
        
        for res in request {
            guard let bookmark = res.value(forKey: "bookmark") as? Data else { return }
            
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmark,
                options: .withoutUI,
                bookmarkDataIsStale: &isStale
            )
            
            guard url.startAccessingSecurityScopedResource() else {
                print("Failed to open the file")
                return
            }
            
            defer {
                url.stopAccessingSecurityScopedResource()
            }
            
            if (isStale) {
                print("Data is stale")
            }
            await self.fetchSong(
                url: url,
                bookmark: bookmark
            )
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
